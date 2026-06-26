/**
 * 数据模型定义
 * 所有与后端交互的数据结构都在这里定义
 */

/** 日程/作息项 */
export interface ScheduleItem {
  id: number;
  user_id: number;
  title: string;
  start_time: string;
  end_time: string;
  category: string;
  color: string;
  reminder_minutes: number;
  repeat_days: string;
  is_active: number;
  created_at: string;
  updated_at: string;
}

/** 打卡记录 */
export interface CheckinRecord {
  id: number;
  user_id: number;
  schedule_id: number;
  check_date: string;
  check_time: string;
  status: string;
  note: string;
  schedule_title: string;
  category: string;
  created_at: string;
}

/** 睡眠记录 */
export interface SleepRecord {
  id: number;
  user_id: number;
  sleep_date: string;
  sleep_time: string;
  wake_time: string;
  duration_minutes: number;
  quality: number;
  sleep_latency: number;
  awakenings: number;
  notes: string;
  created_at: string;
}

/** 今日日程+打卡状态 */
export interface TodaySchedule extends ScheduleItem {
  checked: boolean;
  checkin: CheckinRecord;
}

/** 分页信息 */
export interface Pagination {
  page: number;
  size: number;
  total: number;
  totalPages: number;
}

/** 优化建议 */
export interface Suggestion {
  type: string;
  title: string;
  detail: string;
}

/** 登录响应 */
export interface LoginResponse {
  token: string;
  username: string;
  nickname: string;
}

/** 周分析数据 */
export interface WeeklyData {
  sleep: SleepRecord[];
  checkins: Record<string, Object>[];
  activeSchedules: number;
}
