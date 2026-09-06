"""Turn the bank and card exports into hledger transactions.

Three sources, three shapes. The credit card export is purchases only, so each
one is an expense against liabilities:card. The two bank exports are mixed --
direct debits, transfers, the card settlement -- and the settlement in
particular must become a transfer rather than an expense, or every card
purchase gets counted twice.

Classification is the same set of rules the budget was built from. Anything
that does not match lands in expenses:other and is listed at the end, so the
residue is visible rather than silently absorbed.
"""
import xlrd, openpyxl, datetime, re, sys, collections

CARD = '/Users/robertogoam/Downloads/movimientos tarjeta.xlsx'
MAIN = '/Users/robertogoam/Downloads/Movimientos.xls'
SECOND = '/Users/robertogoam/Downloads/Movimientos_Cuenta_8592_06_08_2024_06 _ 09 _ 2026.xls'
START = datetime.date(2025, 9, 1)

def card_rows():
    wb = openpyxl.load_workbook(CARD, read_only=True, data_only=True)
    for r in wb['movimientos'].iter_rows(min_row=4, values_only=True):
        if not r or r[0] is None: continue
        d = r[0] if isinstance(r[0], datetime.datetime) else datetime.datetime.fromisoformat(str(r[0]))
        if d.date() >= START:
            yield d.date(), float(r[1]), (r[2] or '').strip(), (r[3] or '').strip()

def sheet_rows(path, first, desc_col, amt_col, bal_col):
    b = xlrd.open_workbook(path); sh = b.sheet_by_index(0)
    for i in range(first, sh.nrows):
        v = sh.row_values(i)
        if not v[0]: continue
        try: d = datetime.datetime(*xlrd.xldate_as_tuple(float(v[0]), b.datemode)).date()
        except Exception: continue
        if d >= START:
            yield d, float(v[amt_col]), str(v[desc_col]).strip().strip('"'), float(v[bal_col] or 0)

# ---- classification -------------------------------------------------------
CARD_RULES = [
 ('expenses:travel',                  r'apartamentos|hotel|booking\.com|airbnb|ryanair|vueling|iberia'),
 ('expenses:home:appliances',         r'dysonspains|cecotec|rowenta|panasonic'),
 ('expenses:home:general',            r'cerrajero'),
 ('expenses:clothes',                 r'financiera el corte'),
 ('expenses:health:gym',              r'\bonix\b'),
 ('assets:bank:bunq',                 r'\bbunq\b'),
 ('expenses:subscriptions',           r'uber\s+\*one membership'),
 ('expenses:transport',               r'uber rides'),
 ('expenses:eating-out',              r'paypal \*justeat'),
 ('expenses:gear',                    r'paypal \*ebay'),
 ('expenses:groceries',               r'mercadona|masymas|carrefour|lidl|aldi|consum|spar |superdumbo|avda estacion'),
 ('expenses:eating-out',              r'uber\s*\*?\s*eats|ubr\*|glovo|just eat|restaurant|pizz|burger|cafe|cake|candy|tapas|sushi|kebab|andaluza|\bbar\b|taberna|cerveceria|cervezeria|ragazza|bakeroom|lizarran|mymenu|toma-|concerto|rakia'),
 ('expenses:transport',               r'uber\s+\*trip|teletaxi|taxi|cabify|renfe|alsa|repsol|cepsa|parking|gasolin|\bemt\b|sumup\s*\*taxime'),
 ('expenses:health:dental',           r'kranion|dentista'),
 ('expenses:health:medical',          r'farmacia|clinica|optica'),
 ('expenses:subscriptions',           r'apple\.com/bill|claude|openai|chatgpt|torbox|github|prime|google|obsidian|playstation|paypal \*cookidoo|paypal \*vpshosting'),
 ('expenses:pets',                    r'mascotas|veterinari'),
 ('expenses:clothes',                 r'mango|zara|el corte ingles|primark|decathlon|perfumerias|asics|fluchos'),
 ('expenses:home:general',            r'unigas|milar|ikea|leroy|bricomart'),
 ('expenses:gear',                    r'amazon|amzn|aliexpress|wallapop|ktuin|pccomponentes|mediamarkt|xteink'),
 ('expenses:personal-care:treatments',r'disp\.efect'),
 ('expenses:fees',                    r'comisi|cuota tarjeta'),
]
BANK_RULES = [
 ('TRANSFER:liabilities:card',        r'tarjeta cr[eé]dito particu|ingreso en tarjeta'),
 ('TRANSFER:assets:bank:bunq',        r'\bbunq\b'),
 ('expenses:housing:derrama',         r'trf\. comunidad'),
 ('expenses:home:general',            r'cerrajero'),
 ('expenses:clothes',                 r'financiera el corte'),
 ('TRANSFER:assets:bank:second',      r'trf\.roberto g|trf\.roberto gomez|roberto gomez amores'),
 ('SALARY',                           r'alinventor'),
 ('expenses:housing:mortgage',        r'rcbo\. pr[eé]stamo|prestamo'),
 ('expenses:insurance:house',         r'multitranquilidad'),
 ('expenses:housing:utilities',       r'naturgy|endesa|iberdrola'),
 ('expenses:phone',                   r'yoigo|xfera'),
 ('expenses:housing:community',       r'trf\. periodica'),
 ('expenses:housing:water',           r'aguas alic'),
 ('expenses:housekeeper',             r'BIZUM_HOUSEKEEPER'),
 ('expenses:tax:renta',               r'aeat'),
 ('expenses:tax:local',               r'suma gestion'),
 ('expenses:health:dental',           r'kranion'),
 ('expenses:home:appliances',         r'vorwerk'),
 ('expenses:home:general',            r'bookmeeting'),
 ('expenses:personal-care:treatments',r'^tj-|deutsche bank sae|bancosabadell|eurocaja|bankinter|caixa'),
 ('expenses:fees',                    r'comisi|com\.manto|com\.reintg'),
]
def classify(rules, text):
    t = text.lower()
    for account, pattern in rules:
        if re.search(pattern, t): return account
    return None

def money(x): return "%.2f" % abs(x)

MORT_RATE = (1 + 1.29/100) ** (1/12) - 1
MORT_OPEN = 68386.81

def second_credits():
    """What the second account actually received, so a transfer out of the main
    account is only booked as arriving if it did. One 200 in December left the
    main account under my own name and never landed here."""
    return [(d, amt) for d, amt, desc, bal in sheet_rows(SECOND, 11, 2, 3, 5) if amt > 0]

def main():
    out, unmatched = [], collections.Counter()
    mortgage = [MORT_OPEN]
    credits = second_credits()
    # --- credit card: purchases and refunds -------------------------------
    card_total = 0.0
    for d, amt, kind, payee in card_rows():
        # On the trip, a bar is not eating out and a taxi is not commuting --
        # the whole week is the trip. Foreign currency is what marks it.
        foreign = re.search(r'z/n-euro|extranj|inter z-neu', kind.lower())
        acct = ('expenses:travel' if foreign and not re.search(r'comisi', kind.lower())
                else classify(CARD_RULES, kind + ' ' + payee) or 'expenses:other')
        card_total += amt
        if amt < 0:
            out.append((d, payee or kind, [(acct, -amt), ('liabilities:card', None)]))
        else:
            out.append((d, (payee or kind) + ' refund', [('liabilities:card', amt), (acct, None)]))
        if acct == 'expenses:other': unmatched[payee[:30]] += -amt
    # --- main account ------------------------------------------------------
    main_total = 0.0
    for d, amt, desc, bal in sheet_rows(MAIN, 1, 2, 3, 4):
        main_total += amt
        low = desc.lower()
        # a Bizum of 75-95 is the housekeeper; smaller ones are splitting bills
        if 'bizum' in low and amt < 0:
            acct = 'expenses:housekeeper' if 75 <= -amt <= 95 else 'expenses:other'
            out.append((d, 'bizum', [(acct, -amt), ('assets:bank:main', None)]))
            continue
        target = classify(BANK_RULES, desc)
        if target == 'SALARY':
            out.append((d, 'payslip', [('assets:bank:main', amt), ('income:salary', None)]))
        elif target and target.startswith('TRANSFER:'):
            other = target.split(':', 1)[1]
            if other == 'assets:bank:second':
                hit = next((c for c in credits
                            if abs(c[1] + amt) < 0.01 and abs((c[0] - d).days) <= 3), None)
                if hit: credits.remove(hit)
                else: other = 'expenses:other'   # left, but never arrived here
            out.append((d, desc[:40], [(other, -amt), ('assets:bank:main', None)]))
        elif target == 'expenses:housing:mortgage':
            interest = mortgage[0] * MORT_RATE
            principal = -amt - interest
            mortgage[0] -= principal
            out.append((d, 'mortgage', [('expenses:housing:mortgage', interest),
                                        ('liabilities:mortgage', principal),
                                        ('assets:bank:main', None)]))
        elif amt < 0:
            out.append((d, desc[:40], [(target or 'expenses:other', -amt), ('assets:bank:main', None)]))
            if not target: unmatched[desc[:30]] += -amt
        else:
            out.append((d, desc[:40], [('assets:bank:main', amt), ('income:other', None)]))
    # --- second account ----------------------------------------------------
    second_total = 0.0
    for d, amt, desc, bal in sheet_rows(SECOND, 11, 2, 3, 5):
        second_total += amt
        target = classify(BANK_RULES, desc)
        if target and target.startswith('TRANSFER:'):
            # Already recorded from the main account's side. Booking it again
            # here would move the money twice.
            continue
        if amt < 0:
            acct = target if target and not target.startswith(('TRANSFER','SALARY')) else \
                   ('expenses:subscriptions' if 'paypal' in desc.lower() else 'expenses:other')
            out.append((d, desc[:40], [(acct, -amt), ('assets:bank:second', None)]))
        else:
            out.append((d, desc[:40], [('assets:bank:second', amt), ('income:other', None)]))
    out.sort(key=lambda x: x[0])
    print("; imported %d transactions from the card, main and second accounts" % len(out), file=sys.stderr)
    print("; card movements %.2f, main %.2f, second %.2f" % (card_total, main_total, second_total), file=sys.stderr)
    print("; unmatched, biggest first:", file=sys.stderr)
    for k, v in unmatched.most_common(12):
        print(";   %-34s %8.2f" % (k, v), file=sys.stderr)
    lines = []
    for d, desc, postings in out:
        lines.append("\n%s %s" % (d, re.sub(r'\s+', ' ', desc).strip() or 'movement'))
        for acct, amt in postings:
            lines.append("    %-38s%s" % (acct, ("  %10s EUR" % money(amt)) if amt is not None else ""))
    sys.stdout.write("\n".join(lines) + "\n")

main()
