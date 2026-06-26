/**
 * 应用主题配色 — 薰衣草紫现代风格
 * 设计理念：柔和、清新、护眼，适合日程管理类应用
 */
export class Theme {
  // 主色调 — 薰衣草紫
  static readonly PRIMARY: string = '#6C5CE7';
  static readonly PRIMARY_DARK: string = '#5A4BD1';
  static readonly PRIMARY_LIGHT: string = '#A29BFE';
  static readonly PRIMARY_BG: string = '#F5F3FF';

  // 背景与卡片
  static readonly BG: string = '#F8F9FE';
  static readonly CARD: string = '#FFFFFF';
  static readonly SURFACE: string = '#EEF0FB';

  // 文字
  static readonly TEXT_PRIMARY: string = '#2D3436';
  static readonly TEXT_SECONDARY: string = '#636E72';
  static readonly TEXT_LIGHT: string = '#B2BEC3';

  // 分割线/边框
  static readonly DIVIDER: string = '#E8EAF6';

  // 阴影
  static readonly SHADOW: string = '#14000000';
  static readonly SHADOW_LIGHT: string = '#0A000000';

  // 功能色
  static readonly SUCCESS: string = '#00B894';
  static readonly SUCCESS_LIGHT: string = '#E8F8F5';
  static readonly WARNING: string = '#FDCB6E';
  static readonly WARNING_LIGHT: string = '#FFF9E6';
  static readonly DANGER: string = '#E17055';
  static readonly DANGER_LIGHT: string = '#FDECEA';
  static readonly INFO: string = '#74B9FF';
  static readonly INFO_LIGHT: string = '#EBF5FF';

  // 日程分类颜色
  static readonly CAT_WAKE: string = '#FDCB6E';     // 起床 — 暖黄
  static readonly CAT_STUDY: string = '#6C5CE7';    // 学习 — 紫色
  static readonly CAT_NAP: string = '#00B894';      // 午休 — 薄荷绿
  static readonly CAT_EXERCISE: string = '#E17055'; // 运动 — 珊瑚橘
  static readonly CAT_SLEEP: string = '#A29BFE';    // 睡眠 — 淡紫
  static readonly CAT_OTHER: string = '#74B9FF';    // 其他 — 天蓝

  /**
   * 根据分类返回对应颜色
   */
  static getCategoryColor(category: string): string {
    if (category === 'wake') return Theme.CAT_WAKE;
    if (category === 'study') return Theme.CAT_STUDY;
    if (category === 'nap') return Theme.CAT_NAP;
    if (category === 'exercise') return Theme.CAT_EXERCISE;
    if (category === 'sleep') return Theme.CAT_SLEEP;
    return Theme.CAT_OTHER;
  }

  /**
   * 根据分类返回中文名称
   */
  static getCategoryName(category: string): string {
    if (category === 'wake') return '起床';
    if (category === 'study') return '学习';
    if (category === 'nap') return '午休';
    if (category === 'exercise') return '运动';
    if (category === 'sleep') return '睡眠';
    return '其他';
  }
}
