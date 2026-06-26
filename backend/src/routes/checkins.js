/**
 * 打卡记录路由 (CRUD + 日期筛选 + 分页)
 * GET    /api/checkins                — 查询打卡记录 (支持分页和日期筛选)
 * GET    /api/checkins/today          — 获取今日打卡状态
 * POST   /api/checkins                — 提交打卡
 * PUT    /api/checkins/:id            — 修改打卡备注
 * DELETE /api/checkins/:id            — 删除打卡记录
 */
const express = require('express');
const pool = require('../db');
const auth = require('../middleware/auth');

const router = express.Router();
router.use(auth);

/**
 * GET /
 * 查询打卡记录，支持分页和日期筛选
 * Query: ?page=1&size=20&start=2026-06-01&end=2026-06-30
 */
router.get('/', async (req, res) => {
  try {
    const page = Math.max(1, parseInt(req.query.page) || 1);
    const size = Math.min(50, Math.max(1, parseInt(req.query.size) || 20));
    const offset = (page - 1) * size;
    const { start, end } = req.query;

    // 构建查询条件
    let where = 'WHERE c.user_id = ?';
    const params = [req.userId];

    if (start) {
      where += ' AND c.check_date >= ?';
      params.push(start);
    }
    if (end) {
      where += ' AND c.check_date <= ?';
      params.push(end);
    }

    // 查询总数
    const [countRows] = await pool.query(
      `SELECT COUNT(*) as total FROM checkins c ${where}`, params
    );
    const total = countRows[0].total;

    // 查询数据（关联日程标题）
    const [rows] = await pool.query(
      `SELECT c.*, s.title as schedule_title, s.category
       FROM checkins c
       LEFT JOIN schedules s ON c.schedule_id = s.id
       ${where}
       ORDER BY c.check_date DESC, c.check_time DESC
       LIMIT ? OFFSET ?`,
      [...params, size, offset]
    );

    res.json({
      data: rows,
      pagination: { page, size, total, totalPages: Math.ceil(total / size) }
    });
  } catch (err) {
    console.error('[Checkins] 查询错误:', err.message);
    res.status(500).json({ error: '查询打卡记录失败' });
  }
});

/**
 * GET /today
 * 获取今日所有日程的打卡状态
 * 返回: 今日日程列表 + 每个日程是否已打卡
 */
router.get('/today', async (req, res) => {
  try {
    const today = new Date().toISOString().slice(0, 10);
    const dayOfWeek = new Date().getDay() || 7; // 周日=7

    // 获取今日应执行的日程
    const [schedules] = await pool.query(
      `SELECT * FROM schedules
       WHERE user_id = ? AND is_active = 1
       AND FIND_IN_SET(?, repeat_days)`,
      [req.userId, dayOfWeek]
    );

    // 获取今日打卡记录
    const [checkins] = await pool.query(
      'SELECT schedule_id, status, check_time, note FROM checkins WHERE user_id = ? AND check_date = ?',
      [req.userId, today]
    );

    // 合并：每个日程标记打卡状态
    const checkinMap = {};
    for (const c of checkins) {
      checkinMap[c.schedule_id] = c;
    }

    const result = schedules.map(s => ({
      ...s,
      checked: !!checkinMap[s.id],
      checkin: checkinMap[s.id] || null
    }));

    res.json({ data: result, date: today });
  } catch (err) {
    console.error('[Checkins] 今日状态查询错误:', err.message);
    res.status(500).json({ error: '查询今日打卡状态失败' });
  }
});

/**
 * POST /
 * 提交打卡
 * Body: { schedule_id?, status, note? }
 */
router.post('/', async (req, res) => {
  try {
    const { schedule_id, status, note } = req.body;
    const now = new Date();
    const checkDate = now.toISOString().slice(0, 10);
    const checkTime = now.toISOString().slice(0, 19).replace('T', ' ');

    // 判断打卡状态
    let checkStatus = status || 'on_time';

    // 如果关联了日程，根据时间判断是否迟到
    if (schedule_id) {
      const [schedRows] = await pool.query(
        'SELECT start_time, end_time FROM schedules WHERE id = ? AND user_id = ?',
        [schedule_id, req.userId]
      );
      if (schedRows.length > 0) {
        const sched = schedRows[0];
        const currentMinutes = now.getHours() * 60 + now.getMinutes();
        const startMinutes = parseInt(sched.start_time.split(':')[0]) * 60 + parseInt(sched.start_time.split(':')[1]);
        const endMinutes = parseInt(sched.end_time.split(':')[0]) * 60 + parseInt(sched.end_time.split(':')[1]);

        if (currentMinutes < startMinutes - 30) {
          checkStatus = 'early';   // 提前30分钟以上
        } else if (currentMinutes > endMinutes) {
          checkStatus = 'late';    // 超过结束时间
        }
      }
    }

    // 插入打卡记录 (使用 INSERT IGNORE 避免重复)
    const [result] = await pool.query(
      `INSERT IGNORE INTO checkins (user_id, schedule_id, check_date, check_time, status, note)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [req.userId, schedule_id || null, checkDate, checkTime, checkStatus, note || '']
    );

    if (result.affectedRows === 0) {
      return res.status(409).json({ error: '今日已打卡' });
    }

    res.status(201).json({
      message: '打卡成功',
      id: result.insertId,
      status: checkStatus
    });
  } catch (err) {
    console.error('[Checkins] 打卡错误:', err.message);
    res.status(500).json({ error: '打卡失败' });
  }
});

/**
 * PUT /:id
 * 修改打卡备注
 * Body: { note, status? }
 */
router.put('/:id', async (req, res) => {
  try {
    const { note, status } = req.body;
    const fields = [];
    const values = [];

    if (note !== undefined) { fields.push('note = ?'); values.push(note); }
    if (status !== undefined) { fields.push('status = ?'); values.push(status); }

    if (fields.length === 0) {
      return res.status(400).json({ error: '没有需要更新的字段' });
    }

    values.push(req.params.id, req.userId);
    const [result] = await pool.query(
      `UPDATE checkins SET ${fields.join(', ')} WHERE id = ? AND user_id = ?`,
      values
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ error: '打卡记录不存在' });
    }

    res.json({ message: '更新成功' });
  } catch (err) {
    console.error('[Checkins] 更新错误:', err.message);
    res.status(500).json({ error: '更新打卡记录失败' });
  }
});

/**
 * DELETE /:id
 * 删除打卡记录
 */
router.delete('/:id', async (req, res) => {
  try {
    const [result] = await pool.query(
      'DELETE FROM checkins WHERE id = ? AND user_id = ?',
      [req.params.id, req.userId]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ error: '打卡记录不存在' });
    }

    res.json({ message: '打卡记录已删除' });
  } catch (err) {
    console.error('[Checkins] 删除错误:', err.message);
    res.status(500).json({ error: '删除打卡记录失败' });
  }
});

module.exports = router;
