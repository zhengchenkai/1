/**
 * 作息时间表路由 (完整CRUD)
 * GET    /api/schedules          — 查询当前用户的所有日程
 * GET    /api/schedules/:id      — 查询单个日程详情
 * POST   /api/schedules          — 新增日程
 * PUT    /api/schedules/:id      — 修改日程
 * DELETE /api/schedules/:id      — 删除日程
 */
const express = require('express');
const pool = require('../db');
const auth = require('../middleware/auth');

const router = express.Router();

// 所有日程接口都需要认证
router.use(auth);

/**
 * GET /
 * 获取当前用户所有有效日程，按开始时间排序
 * Query: ?active=1 (可选, 默认只返回启用的)
 */
router.get('/', async (req, res) => {
  try {
    const activeOnly = req.query.active !== '0';
    const sql = activeOnly
      ? 'SELECT * FROM schedules WHERE user_id = ? AND is_active = 1 ORDER BY start_time'
      : 'SELECT * FROM schedules WHERE user_id = ? ORDER BY start_time';

    const [rows] = await pool.query(sql, [req.userId]);
    res.json({ data: rows });
  } catch (err) {
    console.error('[Schedules] 查询错误:', err.message);
    res.status(500).json({ error: '查询日程失败' });
  }
});

/**
 * GET /:id
 * 获取单个日程详情
 */
router.get('/:id', async (req, res) => {
  try {
    const [rows] = await pool.query(
      'SELECT * FROM schedules WHERE id = ? AND user_id = ?',
      [req.params.id, req.userId]
    );
    if (rows.length === 0) {
      return res.status(404).json({ error: '日程不存在' });
    }
    res.json({ data: rows[0] });
  } catch (err) {
    console.error('[Schedules] 查询详情错误:', err.message);
    res.status(500).json({ error: '查询日程详情失败' });
  }
});

/**
 * POST /
 * 新增日程
 * Body: { title, start_time, end_time, category, color, reminder_minutes, repeat_days }
 */
router.post('/', async (req, res) => {
  try {
    const { title, start_time, end_time, category, color, reminder_minutes, repeat_days } = req.body;

    // 参数校验
    if (!title || !start_time || !end_time) {
      return res.status(400).json({ error: '标题、开始时间和结束时间不能为空' });
    }

    const validCategories = ['wake', 'study', 'nap', 'exercise', 'sleep', 'other'];
    const cat = validCategories.includes(category) ? category : 'other';

    const [result] = await pool.query(
      `INSERT INTO schedules
       (user_id, title, start_time, end_time, category, color, reminder_minutes, repeat_days)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        req.userId,
        title,
        start_time,
        end_time,
        cat,
        color || '#6C5CE7',
        reminder_minutes || 0,
        repeat_days || '1,2,3,4,5,6,7'
      ]
    );

    res.status(201).json({
      message: '日程创建成功',
      id: result.insertId
    });
  } catch (err) {
    console.error('[Schedules] 创建错误:', err.message);
    res.status(500).json({ error: '创建日程失败' });
  }
});

/**
 * PUT /:id
 * 修改日程
 * Body: 同 POST，所有字段可选
 */
router.put('/:id', async (req, res) => {
  try {
    const { title, start_time, end_time, category, color, reminder_minutes, repeat_days, is_active } = req.body;

    // 先确认日程属于当前用户
    const [existing] = await pool.query(
      'SELECT id FROM schedules WHERE id = ? AND user_id = ?',
      [req.params.id, req.userId]
    );
    if (existing.length === 0) {
      return res.status(404).json({ error: '日程不存在或无权限' });
    }

    // 动态构建更新字段
    const fields = [];
    const values = [];

    if (title !== undefined) { fields.push('title = ?'); values.push(title); }
    if (start_time !== undefined) { fields.push('start_time = ?'); values.push(start_time); }
    if (end_time !== undefined) { fields.push('end_time = ?'); values.push(end_time); }
    if (category !== undefined) { fields.push('category = ?'); values.push(category); }
    if (color !== undefined) { fields.push('color = ?'); values.push(color); }
    if (reminder_minutes !== undefined) { fields.push('reminder_minutes = ?'); values.push(reminder_minutes); }
    if (repeat_days !== undefined) { fields.push('repeat_days = ?'); values.push(repeat_days); }
    if (is_active !== undefined) { fields.push('is_active = ?'); values.push(is_active); }

    if (fields.length === 0) {
      return res.status(400).json({ error: '没有需要更新的字段' });
    }

    values.push(req.params.id, req.userId);
    await pool.query(
      `UPDATE schedules SET ${fields.join(', ')} WHERE id = ? AND user_id = ?`,
      values
    );

    res.json({ message: '日程更新成功' });
  } catch (err) {
    console.error('[Schedules] 更新错误:', err.message);
    res.status(500).json({ error: '更新日程失败' });
  }
});

/**
 * DELETE /:id
 * 删除日程
 */
router.delete('/:id', async (req, res) => {
  try {
    const [result] = await pool.query(
      'DELETE FROM schedules WHERE id = ? AND user_id = ?',
      [req.params.id, req.userId]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ error: '日程不存在或无权限' });
    }

    res.json({ message: '日程已删除' });
  } catch (err) {
    console.error('[Schedules] 删除错误:', err.message);
    res.status(500).json({ error: '删除日程失败' });
  }
});

module.exports = router;
