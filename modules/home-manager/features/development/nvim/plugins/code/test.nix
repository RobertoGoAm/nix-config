{
  plugins = {
    dap = {
      enable = true;
    };

    dap-ui = {
      enable = true;
    };

    dap-virtual-text = {
      enable = true;
    };

    neotest = {
      enable = true;

      adapters = {
        jest.enable = true;
        playwright.enable = true;
        vitest.enable = true;
      };
    };
  };
}
