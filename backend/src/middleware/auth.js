/**
 * Token认证中间件
 * 从 Authorization: Bearer <token> 头中提取token
 * 验证token有效性并将 user_id 注入 req.userId
 */
const pool = require('../db');

async function auth(req, res, next) {
  try {
    const authHeader = req.headers.authorization || '';
    if (!authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: '未提供认证token' });
    }

    const token = authHeader.slice(7);
    if (!token) {
      return res.status(401).json({ error: 'token为空' });
    }

    // 查询有效会话（未过期）
    const [rows] = await pool.query(
      'SELECT user_id FROM auth_sessions WHERE token = ? AND expires_at > NOW()',
      [token]
    );

    if (rows.length === 0) {
      return res.status(401).json({ error: 'token无效或已过期' });
    }

    // 注入用户ID
    req.userId = rows[0].user_id;
    next();
  } catch (err) {
    console.error('[Auth] 中间件错误:', err.message);
    res.status(500).json({ error: '服务器认证错误' });
  }
}

module.exports = auth;
