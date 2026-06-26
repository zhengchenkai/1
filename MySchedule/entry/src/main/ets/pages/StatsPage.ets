import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { Theme } from '../common/Theme';
import { HttpUtils } from '../common/HttpUtils';
import { SleepRecord, Suggestion } from '../model/Models';

/**
 * 作息分析页面
 * - 周趋势：Canvas 柱状图展示近7天睡眠时长 + 打卡完成率
 * - 优化建议：根据分析结果给出改善建议
 */
@Entry
@Component
struct StatsPage {
  @State currentTab: number = 0;
  @State sleepRecords: SleepRecord[] = [];
  @State activeSchedules: number = 0;
  @State completedCheckins: number = 0;
  @State totalCheckins: number = 0;
  @State avgSleepMinutes: number = 0;
  @State suggestions: Suggestion[] = [];
  @State isLoadingWeekly: boolean = true;
  @State isLoadingSuggestions: boolean = true;

  // Canvas 绘制相关
  @State canvasReady: boolean = false;
  @State canvasW: number = 0;
  @State canvasH: number = 0;
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  aboutToAppear(): void {
    this.loadWeeklyData();
  }

  async loadWeeklyData(): Promise<void> {
    try {
      const response: Record<string, Object> = await HttpUtils.get('/analysis/weekly');
      const sleepRaw: Object = response['sleep'];
      this.sleepRecords = sleepRaw as SleepRecord[];
      const activeRaw: Object = response['activeSchedules'];
      this.activeSchedules = activeRaw as number;

      // 计算平均睡眠时长
      if (this.sleepRecords.length > 0) {
        let total: number = 0;
        for (let i: number = 0; i < this.sleepRecords.length; i++) {
          total = total + this.sleepRecords[i].duration_minutes;
        }
        this.avgSleepMinutes = Math.round(total / this.sleepRecords.length);
      }

      // 从 checkins 数组统计完成率
      const checkinsRaw: Object = response['checkins'];
      const checkinsArr: Record<string, Object>[] = checkinsRaw as Record<string, Object>[];
      this.totalCheckins = checkinsArr.length;
      let completed: number = 0;
      for (let i: number = 0; i < checkinsArr.length; i++) {
        const statusVal: Object = checkinsArr[i]['status'];
        const statusStr: string = statusVal as string;
        if (statusStr === 'completed') {
          completed = completed + 1;
        }
      }
      this.completedCheckins = completed;

      // Canvas 已就绪时立即绘制
      if (this.canvasReady) {
        this.drawChart();
      }
    } catch (err) {
      const error: Error = err as Error;
      promptAction.showToast({ message: '加载分析数据失败: ' + error.message });
    } finally {
      this.isLoadingWeekly = false;
    }
  }

  async loadSuggestions(): Promise<void> {
    this.isLoadingSuggestions = true;
    try {
      const response: Record<string, Object> = await HttpUtils.get('/analysis/suggestions');
      const raw: Object = response['suggestions'];
      this.suggestions = raw as Suggestion[];
    } catch (err) {
      const error: Error = err as Error;
      promptAction.showToast({ message: '加载建议失败: ' + error.message });
    } finally {
      this.isLoadingSuggestions = false;
    }
  }

  /**
   * Canvas 绘制柱状图
   */
  drawChart(): void {
    if (this.canvasW === 0 || this.canvasH === 0) {
      return;
    }

    const ctx: CanvasRenderingContext2D = this.context;
    const w: number = this.canvasW;
    const h: number = this.canvasH;

    ctx.clearRect(0, 0, w, h);

    const records: SleepRecord[] = this.sleepRecords;
    if (records.length === 0) {
      ctx.font = '14vp sans-serif';
      ctx.fillStyle = Theme.TEXT_LIGHT;
      ctx.textAlign = 'center';
      ctx.fillText('暂无睡眠数据', w / 2, h / 2);
      return;
    }

    // 找出最大时长（分钟），用于缩放柱高
    let maxDuration: number = 0;
    for (let i: number = 0; i < records.length; i++) {
      if (records[i].duration_minutes > maxDuration) {
        maxDuration = records[i].duration_minutes;
      }
    }
    if (maxDuration === 0) {
      maxDuration = 600; // 防止除零
    }

    const barCount: number = records.length;
    const sidePadding: number = 20;
    const topPadding: number = 24;
    const bottomPadding: number = 44;
    const chartH: number = h - topPadding - bottomPadding;
    const totalBarSpace: number = w - sidePadding * 2;
    const gap: number = totalBarSpace / barCount * 0.3;
    const barWidth: number = totalBarSpace / barCount - gap;

    for (let i: number = 0; i < barCount; i++) {
      const duration: number = records[i].duration_minutes;
      const barH: number = (duration / maxDuration) * chartH;
      const x: number = sidePadding + i * (barWidth + gap) + gap / 2;
      const y: number = topPadding + chartH - barH;

      // 柱体（渐变效果用纯色模拟，顶部深底部浅）
      ctx.fillStyle = Theme.PRIMARY;
      this.roundRect(ctx, x, y, barWidth, barH, 4);

      // 时长标签（柱体上方）
      const hours: number = Math.floor(duration / 60);
      const mins: number = duration % 60;
      const label: string = hours.toString() + 'h' + (mins > 0 ? mins.toString() : '');
      ctx.font = '10vp sans-serif';
      ctx.fillStyle = Theme.TEXT_SECONDARY;
      ctx.textAlign = 'center';
      ctx.fillText(label, x + barWidth / 2, y - 4);

      // 日期标签（柱体下方）
      const dateStr: string = records[i].sleep_date;
      const dateLabel: string = this.shortDate(dateStr);
      ctx.font = '10vp sans-serif';
      ctx.fillStyle = Theme.TEXT_LIGHT;
      ctx.textAlign = 'center';
      ctx.fillText(dateLabel, x + barWidth / 2, topPadding + chartH + 18);
    }

    // 绘制平均线
    if (this.avgSleepMinutes > 0 && this.avgSleepMinutes <= maxDuration) {
      const avgY: number = topPadding + chartH - (this.avgSleepMinutes / maxDuration) * chartH;
      ctx.strokeStyle = Theme.DANGER;
      ctx.lineWidth = 1;
      ctx.setLineDash([4, 3]);
      ctx.beginPath();
      ctx.moveTo(sidePadding, avgY);
      ctx.lineTo(w - sidePadding, avgY);
      ctx.stroke();
      ctx.setLineDash([]);

      // 平均线标签
      ctx.font = '9vp sans-serif';
      ctx.fillStyle = Theme.DANGER;
      ctx.textAlign = 'left';
      const avgH: number = Math.floor(this.avgSleepMinutes / 60);
      const avgM: number = this.avgSleepMinutes % 60;
      ctx.fillText(
        '均 ' + avgH.toString() + 'h' + avgM.toString(),
        w - sidePadding - 50,
        avgY - 4
      );
    }
  }

  /**
   * Canvas 圆角矩形填充
   */
  roundRect(
    ctx: CanvasRenderingContext2D,
    x: number, y: number,
    w: number, h: number,
    r: number
  ): void {
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.arcTo(x + w, y, x + w, y + h, r);
    ctx.arcTo(x + w, y + h, x, y + h, 0);
    ctx.arcTo(x, y + h, x, y, 0);
    ctx.arcTo(x, y, x + w, y, r);
    ctx.closePath();
    ctx.fill();
  }

  /**
   * 缩短日期为 MM/DD 格式
   */
  shortDate(dateStr: string): string {
    const parts: string[] = dateStr.split('-');
    if (parts.length >= 3) {
      return parts[1] + '/' + parts[2];
    }
    return dateStr;
  }

  /**
   * 格式化分钟为 Xh XXm
   */
  formatDuration(minutes: number): string {
    const h: number = Math.floor(minutes / 60);
    const m: number = minutes % 60;
    if (m === 0) {
      return h.toString() + '小时';
    }
    return h.toString() + '小时' + m.toString() + '分';
  }

  /**
   * 计算打卡完成率百分比
   */
  getCompletionRate(): number {
    if (this.totalCheckins === 0) {
      return 0;
    }
    return Math.round((this.completedCheckins / this.totalCheckins) * 100);
  }

  /**
   * 获取建议类型对应图标
   */
  getSuggestionIcon(type: string): string {
    if (type === 'warning') return '⚠️';
    if (type === 'success') return '✅';
    return '💡';
  }

  /**
   * 获取建议卡片背景色
   */
  getSuggestionBg(type: string): string {
    if (type === 'warning') return Theme.WARNING_LIGHT;
    if (type === 'success') return Theme.SUCCESS_LIGHT;
    return Theme.INFO_LIGHT;
  }

  /**
   * 获取建议卡片左边框色
   */
  getSuggestionBorderColor(type: string): string {
    if (type === 'warning') return Theme.WARNING;
    if (type === 'success') return Theme.SUCCESS;
    return Theme.INFO;
  }

  build() {
    Column() {
      // ===== 顶部标题栏 =====
      Column() {
        Text('作息分析')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.TEXT_PRIMARY)

        Text('了解你的作息规律，持续优化')
          .fontSize(13)
          .fontColor(Theme.TEXT_LIGHT)
          .margin({ top: 4 })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16, bottom: 12 })
      .alignItems(HorizontalAlign.Start)
      .backgroundColor(Theme.CARD)

      // ===== Tab 切换 =====
      Row() {
        ForEach(['周趋势', '优化建议'], (tabName: string, idx: number) => {
          Text(tabName)
            .fontSize(14)
            .fontWeight(this.currentTab === idx ? FontWeight.Medium : FontWeight.Normal)
            .fontColor(this.currentTab === idx ? Theme.PRIMARY : Theme.TEXT_SECONDARY)
            .padding({ left: 20, right: 20, top: 10, bottom: 10 })
            .backgroundColor(this.currentTab === idx ? Theme.PRIMARY_BG : 'transparent')
            .borderRadius(20)
            .onClick(() => {
              this.currentTab = idx;
              if (idx === 1 && this.suggestions.length === 0) {
                this.loadSuggestions();
              }
            })
        }, (tabName: string, idx: number) => idx.toString())
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding(8)
      .backgroundColor(Theme.CARD)
      .margin({ top: 1 })

      // ===== 内容区 =====
      Scroll() {
        Column() {
          if (this.currentTab === 0) {
            this.WeeklyTrendTab()
          } else {
            this.SuggestionsTab()
          }
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
   * Tab 1: 周趋势
   */
  @Builder
  WeeklyTrendTab() {
    if (this.isLoadingWeekly) {
      Row() {
        LoadingProgress()
          .width(32)
          .height(32)
          .color(Theme.PRIMARY)
        Text('加载数据中...')
          .fontSize(14)
          .fontColor(Theme.TEXT_SECONDARY)
          .margin({ left: 8 })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding(60)
    } else {
      // --- 睡眠时长柱状图卡片 ---
      Column() {
        Row() {
          Text('💤')
            .fontSize(18)
          Text('近7天睡眠时长')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(Theme.TEXT_PRIMARY)
            .margin({ left: 6 })
        }
        .width('100%')
        .margin({ bottom: 12 })

        Canvas(this.context)
          .width('100%')
          .height(220)
          .backgroundColor(Theme.CARD)
          .onAreaChange((_oldValue: Area, newValue: Area) => {
            const newW: number = newValue.width as number;
            const newH: number = newValue.height as number;
            if (newW > 0 && newH > 0) {
              this.canvasW = newW;
              this.canvasH = newH;
              this.canvasReady = true;
              this.drawChart();
            }
          })
      }
      .width('100%')
      .padding(16)
      .backgroundColor(Theme.CARD)
      .borderRadius(14)
      .shadow({
        radius: 8,
        color: Theme.SHADOW,
        offsetX: 0,
        offsetY: 2
      })

      // --- 数据概览卡片 ---
      Row() {
        // 平均睡眠
        Column() {
          Text(this.formatDuration(this.avgSleepMinutes))
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.PRIMARY)

          Text('平均睡眠')
            .fontSize(12)
            .fontColor(Theme.TEXT_SECONDARY)
            .margin({ top: 4 })
        }
        .layoutWeight(1)
        .padding(16)
        .backgroundColor(Theme.PRIMARY_BG)
        .borderRadius(12)
        .alignItems(HorizontalAlign.Center)

        Column().width(10)

        // 打卡完成率
        Column() {
          Row() {
            Text(this.getCompletionRate().toString())
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(Theme.SUCCESS)
            Text('%')
              .fontSize(14)
              .fontColor(Theme.SUCCESS)
              .margin({ top: 4 })
          }

          Text('打卡完成率')
            .fontSize(12)
            .fontColor(Theme.TEXT_SECONDARY)
            .margin({ top: 4 })
        }
        .layoutWeight(1)
        .padding(16)
        .backgroundColor(Theme.SUCCESS_LIGHT)
        .borderRadius(12)
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .margin({ top: 14 })

      // --- 详细数据 ---
      Column() {
        Text('本周数据')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.TEXT_PRIMARY)
          .margin({ bottom: 12 })
          .alignSelf(ItemAlign.Start)

        // 活跃日程数
        Row() {
          Text('📋')
            .fontSize(16)
          Text('活跃日程')
            .fontSize(14)
            .fontColor(Theme.TEXT_PRIMARY)
            .margin({ left: 8 })
            .layoutWeight(1)
          Text(this.activeSchedules.toString() + ' 项')
            .fontSize(14)
            .fontColor(Theme.PRIMARY)
            .fontWeight(FontWeight.Medium)
        }
        .width('100%')
        .padding({ top: 12, bottom: 12 })
        .alignItems(VerticalAlign.Center)

        Divider().color(Theme.DIVIDER)

        // 已完成打卡
        Row() {
          Text('✅')
            .fontSize(16)
          Text('已完成打卡')
            .fontSize(14)
            .fontColor(Theme.TEXT_PRIMARY)
            .margin({ left: 8 })
            .layoutWeight(1)
          Text(this.completedCheckins.toString() + ' / ' + this.totalCheckins.toString())
            .fontSize(14)
            .fontColor(Theme.SUCCESS)
            .fontWeight(FontWeight.Medium)
        }
        .width('100%')
        .padding({ top: 12, bottom: 12 })
        .alignItems(VerticalAlign.Center)

        Divider().color(Theme.DIVIDER)

        // 平均入睡时长
        Row() {
          Text('😴')
            .fontSize(16)
          Text('平均睡眠时长')
            .fontSize(14)
            .fontColor(Theme.TEXT_PRIMARY)
            .margin({ left: 8 })
            .layoutWeight(1)
          Text(this.formatDuration(this.avgSleepMinutes))
            .fontSize(14)
            .fontColor(Theme.PRIMARY)
            .fontWeight(FontWeight.Medium)
        }
        .width('100%')
        .padding({ top: 12, bottom: 12 })
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .padding(16)
      .backgroundColor(Theme.CARD)
      .borderRadius(14)
      .shadow({
        radius: 8,
        color: Theme.SHADOW,
        offsetX: 0,
        offsetY: 2
      })
      .margin({ top: 14 })
    }
  }

  /**
   * Tab 2: 优化建议
   */
  @Builder
  SuggestionsTab() {
    if (this.isLoadingSuggestions) {
      Row() {
        LoadingProgress()
          .width(32)
          .height(32)
          .color(Theme.PRIMARY)
        Text('正在生成建议...')
          .fontSize(14)
          .fontColor(Theme.TEXT_SECONDARY)
          .margin({ left: 8 })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding(60)
    } else if (this.suggestions.length === 0) {
      Column() {
        Text('🎉')
          .fontSize(48)
          .margin({ bottom: 8 })
        Text('暂无优化建议')
          .fontSize(15)
          .fontColor(Theme.TEXT_LIGHT)
        Text('你的作息习惯很棒，继续保持！')
          .fontSize(13)
          .fontColor(Theme.TEXT_LIGHT)
          .margin({ top: 4 })
      }
      .width('100%')
      .padding(40)
      .alignItems(HorizontalAlign.Center)
    } else {
      ForEach(this.suggestions, (item: Suggestion, index: number) => {
        Row() {
          // 左侧色条
          Column()
            .width(4)
            .height('100%')
            .backgroundColor(this.getSuggestionBorderColor(item.type))
            .borderRadius(2)

          Column() {
            Row() {
              Text(this.getSuggestionIcon(item.type))
                .fontSize(16)
              Text(item.title)
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(Theme.TEXT_PRIMARY)
                .margin({ left: 6 })
                .layoutWeight(1)
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)

            Text(item.detail)
              .fontSize(13)
              .fontColor(Theme.TEXT_SECONDARY)
              .margin({ top: 8 })
              .lineHeight(20)
          }
          .layoutWeight(1)
          .margin({ left: 12 })
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .padding(16)
        .backgroundColor(this.getSuggestionBg(item.type))
        .borderRadius(12)
        .margin({ bottom: 10 })
      }, (item: Suggestion, index: number) => index.toString())
    }
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

      // 统计（当前页）
      Column() {
        Text('📊')
          .fontSize(20)
        Text('统计')
          .fontSize(11)
          .fontColor(Theme.PRIMARY)
          .fontWeight(FontWeight.Medium)
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)

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
