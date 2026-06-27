import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { Theme } from '../common/Theme';
import { HttpUtils } from '../common/HttpUtils';
import { TodaySchedule } from '../model/Models';

/**
 * 今日打卡页面
 * - 展示今天的日程及打卡状态
 * - 支持一键打卡
 * - 支持记录昨晚睡眠
 */
@Entry
@Component
struct CheckinPage {
  @State todayItems: TodaySchedule[] = [];
  @State sleepQuality: number = 3;
  @State sleepTime: string = '23:00';
  @State wakeTime: string = '07:00';
  @State isLoading: boolean = true;
  @State submittingSleep: boolean = false;
  @State todayDateStr: string = '';

  aboutToAppear(): void {
    const now: Date = new Date();
    const m: number = now.getMonth() + 1;
    const d: number = now.getDate();
    this.todayDateStr = m.toString() + '月' + d.toString() + '日';
    this.loadTodaySchedules();
  }

  async loadTodaySchedules(): Promise<void> {
    try {
      const response: Record<string, Object> = await HttpUtils.get('/checkins/today');
      const rawData: Object = response['data'];
      this.todayItems = rawData as TodaySchedule[];
    } catch (err) {
      const error: Error = err as Error;
      promptAction.showToast({ message: '加载失败: ' + error.message });
    } finally {
      this.isLoading = false;
    }
  }

  async doCheckin(index: number): Promise<void> {
    const item: TodaySchedule = this.todayItems[index];
    if (item.checked) {
      return;
    }
    try {
      const body: Record<string, Object | null> = {
        'schedule_id': item.id as Object
      };
      await HttpUtils.post('/checkins', body);
      // 刷新列表以反映最新打卡状态
      await this.loadTodaySchedules();
      promptAction.showToast({ message: '打卡成功!' });
    } catch (err) {
      const error: Error = err as Error;
      promptAction.showToast({ message: '打卡失败: ' + error.message });
    }
  }

  async submitSleep(): Promise<void> {
    if (this.sleepTime.length === 0 || this.wakeTime.length === 0) {
      promptAction.showToast({ message: '请填写入睡和起床时间' });
      return;
    }
    this.submittingSleep = true;
    try {
      const now: Date = new Date();
      const year: number = now.getFullYear();
      const month: number = now.getMonth() + 1;
      const day: number = now.getDate();
      const monthStr: string = month < 10 ? '0' + month.toString() : month.toString();
      const dayStr: string = day < 10 ? '0' + day.toString() : day.toString();
      const dateStr: string = year.toString() + '-' + monthStr + '-' + dayStr;

      // 入睡时间用昨天日期 + 用户输入的时间 (通常晚上入睡是前一天)
      const yesterday: Date = new Date(now.getTime() - 86400000);
      const yYear: number = yesterday.getFullYear();
      const yMonth: number = yesterday.getMonth() + 1;
      const yDay: number = yesterday.getDate();
      const yMonthStr: string = yMonth < 10 ? '0' + yMonth.toString() : yMonth.toString();
      const yDayStr: string = yDay < 10 ? '0' + yDay.toString() : yDay.toString();
      const yesterdayStr: string = yYear.toString() + '-' + yMonthStr + '-' + yDayStr;

      // 后端需要 DATETIME 格式: YYYY-MM-DD HH:MM:SS
      const sleepDatetime: string = yesterdayStr + ' ' + this.sleepTime + ':00';
      const wakeDatetime: string = dateStr + ' ' + this.wakeTime + ':00';

      const body: Record<string, Object | null> = {
        'sleep_date': dateStr as Object,
        'sleep_time': sleepDatetime as Object,
        'wake_time': wakeDatetime as Object,
        'quality': this.sleepQuality as Object
      };
      await HttpUtils.post('/sleep', body);
      promptAction.showToast({ message: '睡眠记录已保存' });
    } catch (err) {
      const error: Error = err as Error;
      promptAction.showToast({ message: '保存失败: ' + error.message });
    } finally {
      this.submittingSleep = false;
    }
  }

  /** 格式化时间显示，去掉秒 */
  formatTime(timeStr: string): string {
    if (timeStr.length >= 5) {
      return timeStr.substring(0, 5);
    }
    return timeStr;
  }

  build() {
    Column() {
      // ===== 顶部标题栏 =====
      Column() {
        Row() {
          Text('今日打卡')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT_PRIMARY)

          Blank()

          Text(this.todayDateStr)
            .fontSize(14)
            .fontColor(Theme.TEXT_SECONDARY)
        }
        .width('100%')

        Text('完成今天的日程打卡，养成好习惯')
          .fontSize(13)
          .fontColor(Theme.TEXT_LIGHT)
          .margin({ top: 4 })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16, bottom: 12 })
      .backgroundColor(Theme.CARD)

      // ===== 可滚动内容区 =====
      Scroll() {
        Column() {
          // ----- 日程打卡列表 -----
          Text('今日日程')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(Theme.TEXT_PRIMARY)
            .margin({ bottom: 12 })
            .alignSelf(ItemAlign.Start)

          if (this.isLoading) {
            Row() {
              LoadingProgress()
                .width(32)
                .height(32)
                .color(Theme.PRIMARY)
              Text('加载中...')
                .fontSize(14)
                .fontColor(Theme.TEXT_SECONDARY)
                .margin({ left: 8 })
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .padding(40)
          } else if (this.todayItems.length === 0) {
            Column() {
              Text('📋')
                .fontSize(48)
                .margin({ bottom: 8 })
              Text('今天没有日程安排')
                .fontSize(15)
                .fontColor(Theme.TEXT_LIGHT)
              Text('去日程页面添加你的计划吧')
                .fontSize(13)
                .fontColor(Theme.TEXT_LIGHT)
                .margin({ top: 4 })
            }
            .width('100%')
            .padding(40)
            .alignItems(HorizontalAlign.Center)
          } else {
            ForEach(this.todayItems, (item: TodaySchedule, index: number) => {
              this.ScheduleCard(item, index)
            }, (item: TodaySchedule) => item.id.toString())
          }

          // ----- 睡眠记录卡片 -----
          this.SleepRecordCard()
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 16, bottom: 20 })
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
   * 日程打卡卡片
   */
  @Builder
  ScheduleCard(item: TodaySchedule, index: number) {
    Row() {
      // 左侧分类色条
      Column()
        .width(4)
        .height(48)
        .borderRadius(2)
        .backgroundColor(Theme.getCategoryColor(item.category))

      // 中间信息
      Column() {
        Text(item.title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(this.formatTime(item.start_time) + ' - ' + this.formatTime(item.end_time))
          .fontSize(12)
          .fontColor(Theme.TEXT_SECONDARY)
          .margin({ top: 6 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12 })

      // 右侧打卡按钮
      if (item.checked) {
        Row() {
          Text('✓')
            .fontSize(12)
            .fontColor(Theme.SUCCESS)
          Text('已打卡')
            .fontSize(12)
            .fontColor(Theme.SUCCESS)
            .margin({ left: 2 })
        }
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .backgroundColor(Theme.SUCCESS_LIGHT)
        .borderRadius(16)
      } else {
        Button('打卡')
          .type(ButtonType.Normal)
          .fontSize(13)
          .fontColor('#FFFFFF')
          .backgroundColor(Theme.PRIMARY)
          .borderRadius(16)
          .height(32)
          .padding({ left: 16, right: 16 })
          .onClick(() => {
            this.doCheckin(index);
          })
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Theme.CARD)
    .borderRadius(12)
    .shadow({
      radius: 8,
      color: Theme.SHADOW,
      offsetX: 0,
      offsetY: 2
    })
    .alignItems(VerticalAlign.Center)
    .margin({ bottom: 10 })
  }

  /**
   * 分类背景色（淡色）
   */
  getCategoryBgColor(category: string): string {
    if (category === 'wake') return '#FFF9E6';
    if (category === 'study') return Theme.PRIMARY_BG;
    if (category === 'nap') return Theme.SUCCESS_LIGHT;
    if (category === 'exercise') return Theme.DANGER_LIGHT;
    if (category === 'sleep') return '#F0EEFF';
    return '#EBF5FF';
  }

  /**
   * 睡眠记录卡片
   */
  @Builder
  SleepRecordCard() {
    Column() {
      Row() {
        Text('🌙')
          .fontSize(20)
        Text('记录昨晚睡眠')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.TEXT_PRIMARY)
          .margin({ left: 8 })
      }
      .width('100%')
      .margin({ bottom: 16 })

      // 入睡时间
      Row() {
        Text('入睡时间')
          .fontSize(14)
          .fontColor(Theme.TEXT_SECONDARY)
          .width(72)
        TextInput({ text: this.sleepTime, placeholder: '例: 23:00' })
          .type(InputType.Normal)
          .fontSize(15)
          .fontColor(Theme.TEXT_PRIMARY)
          .placeholderColor(Theme.TEXT_LIGHT)
          .backgroundColor(Theme.BG)
          .borderRadius(8)
          .height(38)
          .layoutWeight(1)
          .onChange((value: string) => {
            this.sleepTime = value;
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      // 起床时间
      Row() {
        Text('起床时间')
          .fontSize(14)
          .fontColor(Theme.TEXT_SECONDARY)
          .width(72)
        TextInput({ text: this.wakeTime, placeholder: '例: 07:00' })
          .type(InputType.Normal)
          .fontSize(15)
          .fontColor(Theme.TEXT_PRIMARY)
          .placeholderColor(Theme.TEXT_LIGHT)
          .backgroundColor(Theme.BG)
          .borderRadius(8)
          .height(38)
          .layoutWeight(1)
          .onChange((value: string) => {
            this.wakeTime = value;
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ top: 12 })

      // 睡眠质量评分
      Row() {
        Text('睡眠质量')
          .fontSize(14)
          .fontColor(Theme.TEXT_SECONDARY)
          .width(72)

        Row() {
          ForEach([1, 2, 3, 4, 5], (star: number) => {
            Text(star <= this.sleepQuality ? '★' : '☆')
              .fontSize(24)
              .fontColor(star <= this.sleepQuality ? Theme.WARNING : Theme.TEXT_LIGHT)
              .margin({ left: 4, right: 4 })
              .onClick(() => {
                this.sleepQuality = star;
              })
          }, (star: number) => star.toString())
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ top: 14 })

      // 提交按钮
      Button(this.submittingSleep ? '保存中...' : '保存睡眠记录')
        .type(ButtonType.Normal)
        .width('100%')
        .height(42)
        .fontSize(15)
        .fontColor('#FFFFFF')
        .backgroundColor(Theme.PRIMARY)
        .borderRadius(10)
        .margin({ top: 20 })
        .enabled(!this.submittingSleep)
        .opacity(this.submittingSleep ? 0.6 : 1.0)
        .onClick(() => {
          this.submitSleep();
        })
    }
    .width('100%')
    .padding(18)
    .backgroundColor(Theme.CARD)
    .borderRadius(14)
    .shadow({
      radius: 8,
      color: Theme.SHADOW,
      offsetX: 0,
      offsetY: 2
    })
    .margin({ top: 24 })
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

      // 打卡（当前页）
      Column() {
        Text('✅')
          .fontSize(20)
        Text('打卡')
          .fontSize(11)
          .fontColor(Theme.PRIMARY)
          .fontWeight(FontWeight.Medium)
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)

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

      // 我的
      Column() {
        Text('👤')
          .fontSize(20)
        Text('我的')
          .fontSize(11)
          .fontColor(Theme.TEXT_LIGHT)
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)
      .onClick(() => {
        router.replaceUrl({ url: 'pages/ProfilePage' });
      })
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
