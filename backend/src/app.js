/**
 * 作息管理APP - Express主服务器
 *
 * 启动步骤:
 *   1. mysql -u root -p < sql/init.sql   (初始化数据库)
 *   2. npm install                        (安装依赖)
 *   3. npm start                          (启动服务器, 默认端口3000)
 *
 * API基础路径: http://localhost:3000/api
 */
const express = require('express');
const cors = require('cors');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// ===== 全局中间件 =====
app.use(cors());
app.use(express.json());

// ===== 路由注册 =====
app.use('/api/auth', require('./routes/auth'));
app.use('/api/schedules', require('./routes/schedules'));
app.use('/api/checkins', require('./routes/checkins'));
app.use('/api/sleep', require('./routes/sleep'));
app.use('/api/analysis', require('./routes/analysis'));

// ===== 健康检查 =====
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', time: new Date().toISOString() });
});

// ===== 全局错误处理 =====
app.use((err, req, res, next) => {
  console.error('[Server] 未捕获错误:', err);
  res.status(500).json({ error: '服务器内部错误' });
});

// ===== 启动服务器 =====
app.listen(PORT, () => {
  console.log(`[Server] 作息管理API已启动 → http://localhost:${PORT}/api`);
});
