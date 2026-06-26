/**
 * 数据分析路由
 * GET /api/analysis/weekly          — 一周作息数据汇总
 * GET /api/analysis/monthly         — 月度统计
 * GET /api/analysis/suggestions     — AI优化建议 (基于规则引擎)
 */
const express = require('express');
const pool = require('../db');
const auth = require('../middleware/auth');

const router = express.Router();
router.use(auth);

/**
 * GET /weekly
 * 最近7天作息数据：每日入睡/起床时间、睡眠时长、打卡数
 * Query: ?days=7 (默认7天)
 */
router.get('/weekly', async (req, res) => {
  try {
    const days = Math.min(30, Math.max(1, parseInt(req.query.days) || 7));

    // 最近N天睡眠记录
    const [sleepData] = await pool.query(
      `SELECT sleep_date, sleep_time, wake_time, duration_minutes, quality
       FROM sleep_records
       WHERE user_id = ? AND sleep_date >= DATE_SUB(CURDATE(), INTERVAL ? DAY)
       ORDER BY sleep_date ASC`,
      [req.userId, days]
    );

    // 最近N天打卡统计
    const [checkinData] = await pool.query(
      `SELECT check_date, COUNT(*) as checkin_count,
       SUM(CASE WHEN status = 'on_time' THEN 1 ELSE 0 END) as on_time_count
       FROM checkins
       WHERE user_id = ? AND check_date >= DATE_SUB(CURDATE(), INTERVAL ? DAY)
       GROUP BY check_date
       ORDER BY check_date ASC`,
      [req.userId, days]
    );

    // 日程总数
    const [scheduleCount] = await pool.query(
      'SELECT COUNT(*) as total FROM schedules WHERE user_id = ? AND is_active = 1',
      [req.userId]
    );

    res.json({
      sleep: sleepData,
      checkins: checkinData,
      activeSchedules: scheduleCount[0].total
    });
  } catch (err) {
    console.error('[Analysis] 周数据错误:', err.message);
    res.status(500).json({ error: '查询分析数据失败' });
  }
});

/**
 * GET /monthly
 * 月度统计：平均睡眠时长、打卡率、睡眠质量分布
 */
router.get('/monthly', async (req, res) => {
  try {
    // 月度睡眠统计
    const [sleepStats] = await pool.query(
      `SELECT
        AVG(duration_minutes) as avg_duration,
        AVG(quality) as avg_quality,
        AVG(sleep_latency) as avg_latency,
        MIN(sleep_time) as earliest_sleep,
        MAX(sleep_time) as latest_sleep,
        COUNT(*) as record_count
       FROM sleep_records
       WHERE user_id = ? AND sleep_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)`,
      [req.userId]
    );

    // 月度打卡统计
    const [checkinStats] = await pool.query(
      `SELECT
        COUNT(*) as total_checkins,
        SUM(CASE WHEN status = 'on_time' THEN 1 ELSE 0 END) as on_time_count,
        SUM(CASE WHEN status = 'late' THEN 1 ELSE 0 END) as late_count,
        SUM(CASE WHEN status = 'missed' THEN 1 ELSE 0 END) as missed_count
       FROM checkins
       WHERE user_id = ? AND check_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)`,
      [req.userId]
    );

    // 睡眠质量分布 (1-5分各多少天)
    const [qualityDist] = await pool.query(
      `SELECT quality, COUNT(*) as count
       FROM sleep_records
       WHERE user_id = ? AND sleep_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
       GROUP BY quality ORDER BY quality`,
      [req.userId]
    );

    res.json({
      sleep: sleepStats[0],
      checkins: checkinStats[0],
      qualityDistribution: qualityDist
    });
  } catch (err) {
    console.error('[Analysis] 月度统计错误:', err.message);
    res.status(500).json({ error: '查询月度统计失败' });
  }
});

/**
 * GET /suggestions
 * 基于规则引擎的作息优化建议
 * 分析最近14天数据，生成个性化建议
 */
router.get('/suggestions', async (req, res) => {
  try {
    const suggestions = [];

    // 获取最近14天睡眠数据
    const [sleepData] = await pool.query(
      `SELECT sleep_date, sleep_time, wake_time, duration_minutes, quality, sleep_latency
       FROM sleep_records
       WHERE user_id = ? AND sleep_date >= DATE_SUB(CURDATE(), INTERVAL 14 DAY)
       ORDER BY sleep_date ASC`,
      [req.userId]
    );

    // 获取最近14天打卡数据
    const [checkinData] = await pool.query(
      `SELECT check_date, status FROM checkins
       WHERE user_id = ? AND check_date >= DATE_SUB(CURDATE(), INTERVAL 14 DAY)`,
      [req.userId]
    );

    if (sleepData.length >= 3) {
      // 1. 分析平均睡眠时长
      const avgDuration = sleepData.reduce((sum, r) => sum + r.duration_minutes, 0) / sleepData.length;
      if (avgDuration < 360) {
        suggestions.push({
          type: 'warning',
          title: '睡眠不足',
          detail: `近两周平均睡眠${Math.round(avgDuration / 60)}小时${avgDuration % 60}分钟，低于建议的7-8小时。建议适当提前入睡时间。`
        });
      } else if (avgDuration > 540) {
        suggestions.push({
          type: 'info',
          title: '睡眠偏多',
          detail: `近两周平均睡眠${Math.round(avgDuration / 60)}小时${avgDuration % 60}分钟，超过9小时可能影响白天效率。`
        });
      } else {
        suggestions.push({
          type: 'success',
          title: '睡眠时长达标',
          detail: `平均睡眠${Math.round(avgDuration / 60)}小时${avgDuration % 60}分钟，处于健康范围，继续保持！`
        });
      }

      // 2. 分析作息规律性（入睡时间标准差）
      const sleepMinutes = sleepData.map(r => {
        const parts = r.sleep_time.split(' ')[1].split(':');
        let mins = parseInt(parts[0]) * 60 + parseInt(parts[1]);
        if (mins < 720) mins += 1440; // 凌晨时间+24h便于计算
        return mins;
      });
      const avgSleepMin = sleepMinutes.reduce((a, b) => a + b, 0) / sleepMinutes.length;
      const variance = sleepMinutes.reduce((sum, m) => sum + Math.pow(m - avgSleepMin, 2), 0) / sleepMinutes.length;
      const stdDev = Math.sqrt(variance);

      if (stdDev > 60) {
        suggestions.push({
          type: 'warning',
          title: '入睡时间不规律',
          detail: `入睡时间波动较大（标准差${Math.round(stdDev)}分钟），建议固定每天的上床时间，偏差不超过30分钟。`
        });
      } else {
        suggestions.push({
          type: 'success',
          title: '作息规律良好',
          detail: '入睡时间比较稳定，保持规律的作息有助于提高睡眠质量。'
        });
      }

      // 3. 分析入睡耗时
      const avgLatency = sleepData.reduce((sum, r) => sum + (r.sleep_latency || 0), 0) / sleepData.length;
      if (avgLatency > 30) {
        suggestions.push({
          type: 'warning',
          title: '入睡困难',
          detail: `平均入睡耗时${Math.round(avgLatency)}分钟，建议睡前1小时减少屏幕使用，可以尝试阅读或冥想。`
        });
      }
    } else {
      suggestions.push({
        type: 'info',
        title: '数据不足',
        detail: '睡眠记录不足3天，建议坚持每天记录睡眠，以便获取更准确的分析建议。'
      });
    }

    // 4. 分析打卡完成率
    if (checkinData.length > 0) {
      const onTimeRate = checkinData.filter(c => c.status === 'on_time').length / checkinData.length * 100;
      if (onTimeRate >= 80) {
        suggestions.push({
          type: 'success',
          title: '打卡完成率高',
          detail: `近期打卡准时率${Math.round(onTimeRate)}%，作息执行力很棒！`
        });
      } else if (onTimeRate >= 50) {
        suggestions.push({
          type: 'info',
          title: '打卡仍有提升空间',
          detail: `近期打卡准时率${Math.round(onTimeRate)}%，可以设置提前提醒来帮助按时执行。`
        });
      } else {
        suggestions.push({
          type: 'warning',
          title: '打卡准时率偏低',
          detail: `近期打卡准时率仅${Math.round(onTimeRate)}%，建议检查日程安排是否过于紧凑，适当放宽时间。`
        });
      }
    }

    res.json({ suggestions });
  } catch (err) {
    console.error('[Analysis] 建议生成错误:', err.message);
    res.status(500).json({ error: '生成建议失败' });
  }
});

module.exports = router;
