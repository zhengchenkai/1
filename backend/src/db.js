/**
 * 数据库连接池配置
 * 使用 mysql2/promise 实现异步查询
 * dateStrings 防止 DATE 类型时区偏移
 */
const mysql = require('mysql2/promise');
require('dotenv').config();

const pool = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT) || 3306,
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'db_schedule',
  waitForConnections: true,
  connectionLimit: 10,
  dateStrings: ['DATE'],
  timezone: '+08:00'
});

// 测试连接
pool.getConnection()
  .then(conn => {
    console.log('[DB] MySQL 连接成功');
    conn.release();
  })
  .catch(err => {
    console.error('[DB] MySQL 连接失败:', err.message);
  });

module.exports = pool;
