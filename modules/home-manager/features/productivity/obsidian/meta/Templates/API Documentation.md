---
status: Template
lastUpdated: 2024-04-03
type: template
tags: [template, api-documentation]
---

# {{API Name}} Documentation

## Overview
- **Base URL**: 
- **Version**: 
- **Authentication**: 
- **Rate Limiting**: 

## Authentication
### Methods
- **Bearer Token**
  - Header: `Authorization: Bearer <token>`
  - Token Format: JWT
  - Expiration: 

- **API Key**
  - Header: `X-API-Key: <key>`
  - Format: 
  - Scope: 

## Endpoints

### Resource 1
#### GET /resource1
Retrieve a list of resources.

**Parameters**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| page | integer | No | Page number |
| limit | integer | No | Items per page |
| sort | string | No | Sort field |

**Response**
```json
{
  "data": [
    {
      "id": "string",
      "name": "string",
      "description": "string"
    }
  ],
  "meta": {
    "total": "integer",
    "page": "integer",
    "limit": "integer"
  }
}
```

#### POST /resource1
Create a new resource.

**Request Body**
```json
{
  "name": "string",
  "description": "string"
}
```

**Response**
```json
{
  "id": "string",
  "name": "string",
  "description": "string",
  "created_at": "string"
}
```

### Resource 2
[Similar structure for other endpoints]

## Error Handling
### Error Response Format
```json
{
  "error": {
    "code": "string",
    "message": "string",
    "details": {}
  }
}
```

### Error Codes
| Code | Description |
|------|-------------|
| 400 | Bad Request |
| 401 | Unauthorized |
| 403 | Forbidden |
| 404 | Not Found |
| 429 | Too Many Requests |
| 500 | Internal Server Error |

## Rate Limiting
- **Requests per minute**: 
- **Burst limit**: 
- **Headers**:
  - `X-RateLimit-Limit`
  - `X-RateLimit-Remaining`
  - `X-RateLimit-Reset`

## Pagination
- **Default limit**: 
- **Maximum limit**: 
- **Cursor-based**: Yes/No
- **Offset-based**: Yes/No

## Versioning
- **Strategy**: URL/Header
- **Current Version**: 
- **Deprecated Versions**: 
- **Sunset Policy**: 

## SDK Examples
### JavaScript/TypeScript
```typescript
// Example code
```

### Python
```python
# Example code
```

## Best Practices
- Rate limiting
- Error handling
- Caching
- Retries
- Timeouts

## Changelog
### v1.0.0 (YYYY-MM-DD)
- Initial release
- Features added
- Breaking changes

## References
- [[Related Document 1]]
- [[Related Document 2]]
- External links 