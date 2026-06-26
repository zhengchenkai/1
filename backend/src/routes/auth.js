/**
 * 认证路由
 * POST /api/auth/register  — 注册
 * POST /api/auth/login     — 登录
 * POST /api/auth/logout    — 登出 (需认证)
 * GET  /api/auth/me        — 获取当前用户信息 (需认证)
 */
const express = require('express');
const crypto = require('crypto');
const { v4: uuidv4 } = require('uuid');
const pool = require('../db');
const auth = require('../middleware/auth');

const router = express.Router();

/**
 * PBKDF2 密码哈希
 * @param {string} password 明文密码
 * @param {string} salt 盐值
 * @returns {string} 哈希后的hex字符串
 */
function hashPassword(password, salt) {
  return crypto.pbkdf2Sync(password, salt, 10000, 64, 'sha512').toString('hex');
}

/**
 * POST /register
 * 注册新用户
 * Body: { username, password, nickname? }
 */
router.post('/register', async (req, res) => {
  try {
    const { username, password, nickname } = req.body;

    // 参数校验
    if (!username || !password) {
      return res.status(400).json({ error: '用户名和密码不能为空' });
    }
    if (username.length < 3 || username.length > 50) {
      return res.status(400).json({ error: '用户名长度需3-50字符' });
    }
    if (password.length < 6) {
      return res.status(400).json({ error: '密码至少6位' });
    }

    // 检查用户名是否已存在
    const [existing] = await pool.query(
      'SELECT id FROM users WHERE username = ?', [username]
    );
    if (existing.length > 0) {
      return res.status(409).json({ error: '用户名已存在' });
    }

    // 生成盐值并哈希密码
    const salt = crypto.randomBytes(32).toString('hex');
    const passwordHash = hashPassword(password, salt);

    // 插入用户
    const [result] = await pool.query(
      'INSERT INTO users (username, password_hash, salt, nickname) VALUES (?, ?, ?, ?)',
      [username, passwordHash, salt, nickname || username]
    );

    res.status(201).json({
      message: '注册成功',
      userId: result.insertId
    });
  } catch (err) {
    console.error('[Auth] 注册错误:', err.message);
    res.status(500).json({ error: '注册失败，请稍后重试' });
  }
});

/**
 * POST /login
 * 用户登录，返回token
 * Body: { username, password }
 * Response: { token, username, nickname }
 */
router.post('/login', async (req, res) => {
  try {
    const { username, password } = req.body;

    if (!username || !password) {
      return res.status(400).json({ error: '用户名和密码不能为空' });
    }

    // 查找用户
    const [users] = await pool.query(
      'SELECT id, username, nickname, password_hash, salt FROM users WHERE username = ?',
      [username]
    );
    if (users.length === 0) {
      return res.status(401).json({ error: '用户名或密码错误' });
    }

    const user = users[0];

    // 验证密码
    const inputHash = hashPassword(password, user.salt);
    if (inputHash !== user.password_hash) {
      return res.status(401).json({ error: '用户名或密码错误' });
    }

    // 生成token并存入会话表
    const token = uuidv4();
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000); // 7天有效期

    await pool.query(
      'INSERT INTO auth_sessions (user_id, token, expires_at) VALUES (?, ?, ?)',
      [user.id, token, expiresAt]
    );

    res.json({
      token,
      username: user.username,
      nickname: user.nickname
    });
  } catch (err) {
    console.error('[Auth] 登录错误:', err.message);
    res.status(500).json({ error: '登录失败，请稍后重试' });
  }
});

/**
 * POST /logout
 * 登出，删除当前会话token
 * 需要 Authorization: Bearer <token>
 */
router.post('/logout', auth, async (req, res) => {
  try {
    const token = req.headers.authorization.slice(7);
    await pool.query('DELETE FROM auth_sessions WHERE token = ?', [token]);
    res.json({ message: '已登出' });
  } catch (err) {
    console.error('[Auth] 登出错误:', err.message);
    res.status(500).json({ error: '登出失败' });
  }
});

/**
 * GET /me
 * 获取当前登录用户信息
 */
router.get('/me', auth, async (req, res) => {
  try {
    const [users] = await pool.query(
      'SELECT id, username, nickname, created_at FROM users WHERE id = ?',
      [req.userId]
    );
    if (users.length === 0) {
      return res.status(404).json({ error: '用户不存在' });
    }
    res.json(users[0]);
  } catch (err) {
    console.error('[Auth] 获取用户信息错误:', err.message);
    res.status(500).json({ error: '获取用户信息失败' });
  }
});

module.exports = router;
