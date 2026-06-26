-- ============================================================
-- 作息管理APP 数据库初始化脚本
-- 数据库名: db_schedule
-- 使用: mysql -u root -p < sql/init.sql
-- ============================================================

DROP DATABASE IF EXISTS db_schedule;
CREATE DATABASE db_schedule DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE db_schedule;

-- 用户表
CREATE TABLE users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(50) NOT NULL UNIQUE COMMENT '登录用户名',
  password_hash VARCHAR(255) NOT NULL COMMENT 'PBKDF2哈希密码',
  salt VARCHAR(64) NOT NULL COMMENT '密码盐值',
  nickname VARCHAR(100) DEFAULT '' COMMENT '昵称',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 会话表 (token认证)
CREATE TABLE auth_sessions (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  token VARCHAR(128) NOT NULL UNIQUE COMMENT 'opaque token',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  expires_at TIMESTAMP NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 作息时间表
CREATE TABLE schedules (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  title VARCHAR(100) NOT NULL COMMENT '事项标题',
  start_time TIME NOT NULL COMMENT '开始时间',
  end_time TIME NOT NULL COMMENT '结束时间',
  category ENUM('wake','study','nap','exercise','sleep','other') NOT NULL DEFAULT 'other' COMMENT '分类',
  color VARCHAR(7) DEFAULT '#6C5CE7' COMMENT '显示颜色',
  reminder_minutes INT DEFAULT 0 COMMENT '提前提醒分钟数,0=不提醒',
  repeat_days VARCHAR(20) DEFAULT '1,2,3,4,5,6,7' COMMENT '重复日,逗号分隔1-7',
  is_active TINYINT(1) DEFAULT 1 COMMENT '是否启用',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_user_active (user_id, is_active)
) ENGINE=InnoDB;

-- 打卡记录
CREATE TABLE checkins (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  schedule_id INT DEFAULT NULL COMMENT '关联的日程(可为空=自由打卡)',
  check_date DATE NOT NULL COMMENT '打卡日期',
  check_time DATETIME NOT NULL COMMENT '实际打卡时间',
  status ENUM('on_time','late','missed','early') DEFAULT 'on_time' COMMENT '打卡状态',
  note VARCHAR(500) DEFAULT '' COMMENT '打卡备注',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (schedule_id) REFERENCES schedules(id) ON DELETE SET NULL,
  UNIQUE KEY uk_user_schedule_date (user_id, schedule_id, check_date),
  INDEX idx_user_date (user_id, check_date)
) ENGINE=InnoDB;

-- 睡眠质量记录
CREATE TABLE sleep_records (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  sleep_date DATE NOT NULL COMMENT '记录日期',
  sleep_time DATETIME NOT NULL COMMENT '入睡时间',
  wake_time DATETIME NOT NULL COMMENT '起床时间',
  duration_minutes INT NOT NULL COMMENT '睡眠时长(分钟)',
  quality INT DEFAULT 3 COMMENT '睡眠质量1-5分',
  sleep_latency INT DEFAULT 0 COMMENT '入睡耗时(分钟)',
  awakenings INT DEFAULT 0 COMMENT '夜间醒来次数',
  notes VARCHAR(500) DEFAULT '' COMMENT '备注',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE KEY uk_user_date (user_id, sleep_date),
  INDEX idx_user_date (user_id, sleep_date)
) ENGINE=InnoDB;
