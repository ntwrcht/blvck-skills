---
max_turns: 8
allowed_tools: [Skill, Read, Glob, Grep]
---

Is our JWT check safe? No repo here, code below.

```ts
import jwt from 'jsonwebtoken';

export function verifyToken(token: string) {
  const decoded = jwt.decode(token, { complete: true });
  if (decoded?.header.alg === 'none') return decoded.payload;
  return jwt.verify(token, process.env.JWT_SECRET!);
}
```
