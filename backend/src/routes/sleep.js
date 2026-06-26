/**
 * 睡眠记录路由 (CRUD)
 * GET    /api/sleep              — 查询睡眠记录 (支持日期范围)
 * GET    /api/sleep/latest       — 获取最近一条睡眠记录
 * POST   /api/sleep              — 新增/更新睡眠记录
 * PUT    /api/sleep/:id          — 修改睡眠记录
 * DELETE /api/sleep/:id          — 删除睡眠记录
 */
const express = require('express');
const pool = require('../db');
const auth = require('../middleware/auth');

const router = express.Router();
router.use(auth);

/**
 * GET /
 * 查询睡眠记录，支持日期范围
 * Query: ?start=2026-06-01&end=2026-06-30&limit=30
 */
router.get('/', async (req, res) => {
  try {
    const { start, end } = req.query;
    const limit = Math.min(90, Math.max(1, parseInt(req.query.limit) || 30));

    let where = 'WHERE user_id = ?';
    const params = [req.userId];

    if (start) {
      where += ' AND sleep_date >= ?';
      params.push(start);
    }
    if (end) {
      where += ' AND sleep_date <= ?';
      params.push(end);
    }

    const [rows] = await pool.query(
      `SELECT * FROM sleep_records ${where}
       ORDER BY sleep_date DESC LIMIT ?`,
      [...params, limit]
    );

    res.json({ data: rows });
  } catch (err) {
    console.error('[Sleep] 查询错误:', err.message);
    res.status(500).json({ error: '查询睡眠记录失败' });
  }
});

/**
 * GET /latest
 * 获取最近一条睡眠记录
 */
router.get('/latest', async (req, res) => {
  try {
    const [rows] = await pool.query(
      'SELECT * FROM sleep_records WHERE user_id = ? ORDER BY sleep_date DESC LIMIT 1',
      [req.userId]
    );
    res.json({ data: rows[0] || null });
  } catch (err) {
    console.error('[Sleep] 查询最近记录错误:', err.message);
    res.status(500).json({ error: '查询失败' });
  }
});

/**
 * POST /
 * 新增睡眠记录（同日期自动覆盖更新）
 * Body: { sleep_date, sleep_time, wake_time, quality, sleep_latency?, awakenings?, notes? }
 */
router.post('/', async (req, res) => {
  try {
    const { sleep_date, sleep_time, wake_time, quality, sleep_latency, awakenings, notes } = req.body;

    if (!sleep_date || !sleep_time || !wake_time) {
      return res.status(400).json({ error: '日期、入睡时间和起床时间不能为空' });
    }

    // 计算睡眠时长（分钟）
    const sleepMs = new Date(sleep_time).getTime();
    const wakeMs = new Date(wake_time).getTime();
    const durationMinutes = Math.round((wakeMs - sleepMs) / 60000);

    if (durationMinutes <= 0 || durationMinutes > 1440) {
      return res.status(400).json({ error: '睡眠时长不合法' });
    }

    // 使用 ON DUPLICATE KEY UPDATE 实现同日期覆盖
    const [result] = await pool.query(
      `INSERT INTO sleep_records
       (user_id, sleep_date, sleep_time, wake_time, duration_minutes, quality, sleep_latency, awakenings, notes)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE
       sleep_time = VALUES(sleep_time),
       wake_time = VALUES(wake_time),
       duration_minutes = VALUES(duration_minutes),
       quality = VALUES(quality),
       sleep_latency = VALUES(sleep_latency),
       awakenings = VALUES(awakenings),
       notes = VALUES(notes)`,
      [
        req.userId,
        sleep_date,
        sleep_time,
        wake_time,
        durationMinutes,
        quality || 3,
        sleep_latency || 0,
        awakenings || 0,
        notes || ''
      ]
    );

    res.status(201).json({
      message: '睡眠记录保存成功',
      id: result.insertId,
      duration_minutes: durationMinutes
    });
  } catch (err) {
    console.error('[Sleep] 创建错误:', err.message);
    res.status(500).json({ error: '保存睡眠记录失败' });
  }
});

/**
 * PUT /:id
 * 修改睡眠记录
 */
router.put('/:id', async (req, res) => {
  try {
    const { sleep_time, wake_time, quality, sleep_latency, awakenings, notes } = req.body;

    // 确认记录属于当前用户
    const [existing] = await pool.query(
      'SELECT id FROM sleep_records WHERE id = ? AND user_id = ?',
      [req.params.id, req.userId]
    );
    if (existing.length === 0) {
      return res.status(404).json({ error: '记录不存在' });
    }

    const fields = [];
    const values = [];

    if (sleep_time !== undefined) { fields.push('sleep_time = ?'); values.push(sleep_time); }
    if (wake_time !== undefined) { fields.push('wake_time = ?'); values.push(wake_time); }
    if (quality !== undefined) { fields.push('quality = ?'); values.push(quality); }
    if (sleep_latency !== undefined) { fields.push('sleep_latency = ?'); values.push(sleep_latency); }
    if (awakenings !== undefined) { fields.push('awakenings = ?'); values.push(awakenings); }
    if (notes !== undefined) { fields.push('notes = ?'); values.push(notes); }

    // 如果同时更新了入睡和起床时间，重算时长
    if (sleep_time && wake_time) {
      const duration = Math.round((new Date(wake_time).getTime() - new Date(sleep_time).getTime()) / 60000);
      fields.push('duration_minutes = ?');
      values.push(duration);
    }

    if (fields.length === 0) {
      return res.status(400).json({ error: '没有需要更新的字段' });
    }

    values.push(req.params.id, req.userId);
    await pool.query(
      `UPDATE sleep_records SET ${fields.join(', ')} WHERE id = ? AND user_id = ?`,
      values
    );

    res.json({ message: '睡眠记录更新成功' });
  } catch (err) {
    console.error('[Sleep] 更新错误:', err.message);
    res.status(500).json({ error: '更新睡眠记录失败' });
  }
});

/**
 * DELETE /:id
 * 删除睡眠记录
 */
router.delete('/:id', async (req, res) => {
  try {
    const [result] = await pool.query(
      'DELETE FROM sleep_records WHERE id = ? AND user_id = ?',
      [req.params.id, req.userId]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ error: '记录不存在' });
    }

    res.json({ message: '睡眠记录已删除' });
  } catch (err) {
    console.error('[Sleep] 删除错误:', err.message);
    res.status(500).json({ error: '删除睡眠记录失败' });
  }
});

module.exports = router;
