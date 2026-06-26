import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { Theme } from '../common/Theme';
import { HttpUtils } from '../common/HttpUtils';

/** 月度统计数据 */
interface MonthlyStats {
  totalCheckinDays: number;
  avgSleepMinutes: number;
  streak: number;
}

/**
 * 个人中心页面
 * - 展示用户信息和头像
 * - 月度统计摘要
 * - 设置项与退出登录
 */
@Entry
@Component
struct ProfilePage {
  @StorageLink('authUsername') username: string = '';
  @StorageLink('authNickname') nickname: string = '';
  @StorageLink('isLoggedIn') isLoggedIn: boolean = false;

  @State totalCheckinDays: number = 0;
  @State avgSleepMinutes: number = 0;
  @State streak: number = 0;
  @State isLoading: boolean = true;
  @State isLoggingOut: boolean = false;

  aboutToAppear(): void {
    if (!this.isLoggedIn) {
      router.replaceUrl({ url: 'pages/LoginPage' });
      return;
    }
    this.loadMonthlyStats();
  }

  async loadMonthlyStats(): Promise<void> {
    try {
      const response: Record<string, Object> = await HttpUtils.get('/analysis/monthly');
      const dataRaw: Object = response['data'];
      const data: MonthlyStats = dataRaw as MonthlyStats;
      this.totalCheckinDays = data.totalCheckinDays;
      this.avgSleepMinutes = data.avgSleepMinutes;
      this.streak = data.streak;
    } catch (err) {
      const error: Error = err as Error;
      promptAction.showToast({ message: '加载统计失败: ' + error.message });
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 格式化分钟为可读字符串
   */
  formatDuration(minutes: number): string {
    const h: number = Math.floor(minutes / 60);
    const m: number = minutes % 60;
    if (h === 0) {
      return m.toString() + '分钟';
    }
    if (m === 0) {
      return h.toString() + '小时';
    }
    return h.toString() + 'h' + m.toString() + 'm';
  }

  /**
   * 获取用户名首字母用于头像
   */
  getAvatarLetter(): string {
    if (this.username.length > 0) {
      return this.username.charAt(0).toUpperCase();
    }
    return 'U';
  }

  /**
   * 获取显示名称
   */
  getDisplayName(): string {
    if (this.nickname.length > 0) {
      return this.nickname;
    }
    if (this.username.length > 0) {
      return this.username;
    }
    return '未登录';
  }

  async doLogout(): Promise<void> {
    promptAction.showDialog({
      title: '退出登录',
      message: '确定要退出当前账号吗？',
      buttons: [
        { text: '取消', color: Theme.TEXT_SECONDARY },
        { text: '确定', color: Theme.DANGER }
      ]
    }).then(async (result: promptAction.ShowDialogSuccessResponse) => {
      if (result.index === 1) {
        this.isLoggingOut = true;
        try {
          await HttpUtils.post('/auth/logout', {});
        } catch (err) {
          // 即使请求失败也继续清除本地状态
          const error: Error = err as Error;
          console.error('退出请求失败: ' + error.message);
        }
        // 清除本地存储
        AppStorage.setOrCreate<string>('authToken', '');
        AppStorage.setOrCreate<string>('authUsername', '');
        AppStorage.setOrCreate<string>('authNickname', '');
        AppStorage.setOrCreate<boolean>('isLoggedIn', false);
        router.replaceUrl({ url: 'pages/LoginPage' });
      }
    });
  }

  build() {
    Column() {
      // ===== 可滚动内容区 =====
      Scroll() {
        Column() {
          // ----- 用户信息头部 -----
          this.UserHeader()

          // ----- 月度统计卡片 -----
          this.StatsSummary()

          // ----- 设置列表 -----
          this.SettingsList()
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 0, bottom: 20 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)

      // ===== 底部导航栏 =====
      this.BottomNavBar()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BG)
  }

  /**
   * 用户头部信息区
   */
  @Builder
  UserHeader() {
    Column() {
      // 头像圆形
      Column() {
        Text(this.getAvatarLetter())
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
      }
      .width(72)
      .height(72)
      .borderRadius(36)
      .backgroundColor(Theme.PRIMARY)
      .justifyContent(FlexAlign.Center)
      .shadow({
        radius: 12,
        color: '#2A6C5CE7',
        offsetX: 0,
        offsetY: 4
      })

      // 显示名称
      Text(this.getDisplayName())
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.TEXT_PRIMARY)
        .margin({ top: 14 })

      // 用户名
      if (this.username.length > 0 && this.nickname.length > 0) {
        Text('@' + this.username)
          .fontSize(13)
          .fontColor(Theme.TEXT_SECONDARY)
          .margin({ top: 4 })
      }
    }
    .width('100%')
    .padding({ top: 32, bottom: 24 })
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(Theme.CARD)
    .borderRadius({ bottomLeft: 20, bottomRight: 20 })
    .margin({ left: -16, right: -16 })
  }

  /**
   * 月度统计摘要
   */
  @Builder
  StatsSummary() {
    if (this.isLoading) {
      Row() {
        LoadingProgress()
          .width(28)
          .height(28)
          .color(Theme.PRIMARY)
        Text('加载中...')
          .fontSize(13)
          .fontColor(Theme.TEXT_SECONDARY)
          .margin({ left: 8 })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ top: 24, bottom: 24 })
    } else {
      Row() {
        // 总打卡天数
        Column() {
          Text(this.totalCheckinDays.toString())
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.PRIMARY)
          Text('总打卡天数')
            .fontSize(11)
            .fontColor(Theme.TEXT_SECONDARY)
            .margin({ top: 6 })
        }
        .layoutWeight(1)
        .padding(16)
        .backgroundColor(Theme.PRIMARY_BG)
        .borderRadius(14)
        .alignItems(HorizontalAlign.Center)

        Column().width(10)

        // 平均睡眠
        Column() {
          Text(this.formatDuration(this.avgSleepMinutes))
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0984E3')
          Text('平均睡眠')
            .fontSize(11)
            .fontColor(Theme.TEXT_SECONDARY)
            .margin({ top: 6 })
        }
        .layoutWeight(1)
        .padding(16)
        .backgroundColor('#EBF5FF')
        .borderRadius(14)
        .alignItems(HorizontalAlign.Center)

        Column().width(10)

        // 连续打卡
        Column() {
          Text(this.streak.toString())
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.SUCCESS)
          Text('连续打卡')
            .fontSize(11)
            .fontColor(Theme.TEXT_SECONDARY)
            .margin({ top: 6 })
        }
        .layoutWeight(1)
        .padding(16)
        .backgroundColor(Theme.SUCCESS_LIGHT)
        .borderRadius(14)
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .margin({ top: 20 })
    }
  }

  /**
   * 设置列表
   */
  @Builder
  SettingsList() {
    Column() {
      // --- 提醒设置 ---
      Row() {
        Row() {
          Text('🔔')
            .fontSize(18)
          Text('提醒设置')
            .fontSize(15)
            .fontColor(Theme.TEXT_PRIMARY)
            .margin({ left: 10 })
        }
        .layoutWeight(1)
        .alignItems(VerticalAlign.Center)

        Text('暂未开放')
          .fontSize(12)
          .fontColor(Theme.TEXT_LIGHT)

        Text('>')
          .fontSize(16)
          .fontColor(Theme.TEXT_LIGHT)
          .margin({ left: 8 })
      }
      .width('100%')
      .height(54)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)

      Divider().color(Theme.DIVIDER).margin({ left: 16, right: 16 })

      // --- 关于应用 ---
      Row() {
        Row() {
          Text('ℹ️')
            .fontSize(18)
          Text('关于应用')
            .fontSize(15)
            .fontColor(Theme.TEXT_PRIMARY)
            .margin({ left: 10 })
        }
        .layoutWeight(1)
        .alignItems(VerticalAlign.Center)

        Text('v1.0.0')
          .fontSize(12)
          .fontColor(Theme.TEXT_LIGHT)

        Text('>')
          .fontSize(16)
          .fontColor(Theme.TEXT_LIGHT)
          .margin({ left: 8 })
      }
      .width('100%')
      .height(54)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        promptAction.showDialog({
          title: '关于日程管理',
          message: '日程管理 v1.0.0\n\n一款帮助你养成良好作息习惯的应用。\n支持日程规划、每日打卡、睡眠记录与作息分析。',
          buttons: [
            { text: '知道了', color: Theme.PRIMARY }
          ]
        });
      })

      Divider().color(Theme.DIVIDER).margin({ left: 16, right: 16 })

      // --- 退出登录 ---
      Button(this.isLoggingOut ? '退出中...' : '退出登录')
        .type(ButtonType.Normal)
        .width('100%')
        .height(46)
        .fontSize(15)
        .fontColor(Theme.DANGER)
        .backgroundColor(Theme.DANGER_LIGHT)
        .borderRadius(10)
        .margin({ top: 24 })
        .enabled(!this.isLoggingOut)
        .opacity(this.isLoggingOut ? 0.6 : 1.0)
        .onClick(() => {
          this.doLogout();
        })
    }
    .width('100%')
    .padding({ top: 4, bottom: 16 })
    .backgroundColor(Theme.CARD)
    .borderRadius(14)
    .shadow({
      radius: 8,
      color: Theme.SHADOW,
      offsetX: 0,
      offsetY: 2
    })
    .margin({ top: 20 })
  }

  /**
   * 底部导航栏
   */
  @Builder
  BottomNavBar() {
    Row() {
      // 日程
      Column() {
        Text('📅')
          .fontSize(20)
        Text('日程')
          .fontSize(11)
          .fontColor(Theme.TEXT_LIGHT)
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)
      .onClick(() => {
        router.replaceUrl({ url: 'pages/SchedulePage' });
      })

      // 打卡
      Column() {
        Text('✅')
          .fontSize(20)
        Text('打卡')
          .fontSize(11)
          .fontColor(Theme.TEXT_LIGHT)
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)
      .onClick(() => {
        router.replaceUrl({ url: 'pages/CheckinPage' });
      })

      // 统计
      Column() {
        Text('📊')
          .fontSize(20)
        Text('统计')
          .fontSize(11)
          .fontColor(Theme.TEXT_LIGHT)
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)
      .onClick(() => {
        router.replaceUrl({ url: 'pages/StatsPage' });
      })

      // 我的（当前页）
      Column() {
        Text('👤')
          .fontSize(20)
        Text('我的')
          .fontSize(11)
          .fontColor(Theme.PRIMARY)
          .fontWeight(FontWeight.Medium)
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height(56)
    .backgroundColor(Theme.CARD)
    .border({
      width: { top: 1 },
      color: { top: Theme.DIVIDER }
    })
    .alignItems(VerticalAlign.Center)
  }
}
