import { router } from '@kit.ArkUI'
import { promptAction } from '@kit.ArkUI'
import { Theme } from '../common/Theme'
import { HttpUtils } from '../common/HttpUtils'
import { ScheduleItem } from '../model/Models'

interface TabInfo {
  icon: string
  activeIcon: string
  title: string
  url: string
  index: number
}

interface WeekDateItem {
  dayIndex: number
  dayLabel: string
  dateNum: string
  monthDay: string
  isToday: boolean
}

interface SortOptionItem {
  key: string
  label: string
}

@Entry
@Component
struct SchedulePage {
  @State scheduleList: ScheduleItem[] = []
  @State isLoading: boolean = false
  @State currentDate: string = ''
  @State currentMonthYear: string = ''
  @State currentTab: number = 0
  @State weekDates: WeekDateItem[] = []
  @State selectedDayIndex: number = -1
  @State showSortPanel: boolean = false
  @State currentSortKey: string = 'startTime'
  @State allSchedules: ScheduleItem[] = []

  private tabs: TabInfo[] = [
    { icon: '\u25A1', activeIcon: '\u25A0', title: '\u65E5\u7A0B', url: 'pages/SchedulePage', index: 0 },
    { icon: '\u25CB', activeIcon: '\u25CF', title: '\u6253\u5361', url: 'pages/CheckinPage', index: 1 },
    { icon: '\u25B3', activeIcon: '\u25B2', title: '\u7EDF\u8BA1', url: 'pages/StatsPage', index: 2 },
    { icon: '\u25CB', activeIcon: '\u25CF', title: '\u6211\u7684', url: 'pages/ProfilePage', index: 3 }
  ]

  private sortOptions: SortOptionItem[] = [
    { key: 'startTime', label: '\u6309\u5F00\u59CB\u65F6\u95F4' },
    { key: 'createdAt', label: '\u6309\u521B\u5EFA\u65F6\u95F4' },
    { key: 'category', label: '\u6309\u5206\u7C7B' }
  ]

  aboutToAppear(): void {
    this.calculateWeekDates()
  }

  onPageShow(): void {
    this.loadSchedules()
  }

  private calculateWeekDates(): void {
    let now: Date = new Date()
    let todayDow: number = now.getDay()
    let dates: WeekDateItem[] = []
    let dayLabels: string[] = ['\u65E5', '\u4E00', '\u4E8C', '\u4E09', '\u56DB', '\u4E94', '\u516D']
    for (let i: number = 0; i < 7; i++) {
      let d: Date = new Date(now.getTime() + (i - todayDow) * 86400000)
      let dateNum: string = d.getDate().toString()
      let monthDay: string = (d.getMonth() + 1).toString() + '/' + d.getDate().toString()
      let wd: WeekDateItem = {
        dayIndex: d.getDay(),
        dayLabel: dayLabels[d.getDay()],
        dateNum: dateNum,
        monthDay: monthDay,
        isToday: i === todayDow
      }
      dates.push(wd)
    }
    this.weekDates = dates
    let year: number = now.getFullYear()
    let month: number = now.getMonth() + 1
    this.currentMonthYear = year.toString() + '.' + (month < 10 ? '0' + month.toString() : month.toString())
    let day: number = now.getDate()
    let weekDay: string = dayLabels[todayDow]
    this.currentDate = year.toString() + '\u5E74' + month.toString() + '\u6708' + day.toString() + '\u65E5 \u5468' + weekDay
    if (this.selectedDayIndex < 0) {
      this.selectedDayIndex = todayDow
    }
    this.loadSchedules()
  }

  async loadSchedules(): Promise<void> {
    if (this.selectedDayIndex < 0) {
      return
    }
    this.isLoading = true
    try {
      let response: Record<string, Object> = await HttpUtils.get('/schedules') as Record<string, Object>
      let all: ScheduleItem[] = response['data'] as ScheduleItem[]
      this.allSchedules = all
      let dayNum: number = this.selectedDayIndex > 0 ? this.selectedDayIndex : 7
      let dayStr: string = dayNum.toString()
      let filtered: ScheduleItem[] = []
      for (let i: number = 0; i < all.length; i++) {
        let item: ScheduleItem = all[i]
        if (item.repeat_days !== null && item.repeat_days !== undefined) {
          let parts: string[] = item.repeat_days.split(',')
          for (let j: number = 0; j < parts.length; j++) {
            if (parts[j].trim() === dayStr) {
              filtered.push(item)
              break
            }
          }
        }
      }
      this.sortAndSet(filtered)
    } catch (e) {
      promptAction.showToast({ message: '\u52A0\u8F7D\u5931\u8D25\uFF0C\u8BF7\u7A0D\u540E\u91CD\u8BD5' })
    }
    this.isLoading = false
  }

  private sortAndSet(items: ScheduleItem[]): void {
    let sorted: ScheduleItem[] = items
    if (this.currentSortKey === 'startTime') {
      sorted.sort((a: ScheduleItem, b: ScheduleItem): number => {
        if (a.start_time < b.start_time) { return -1 }
        if (a.start_time > b.start_time) { return 1 }
        return 0
      })
    } else if (this.currentSortKey === 'createdAt') {
      sorted.sort((a: ScheduleItem, b: ScheduleItem): number => {
        if (a.created_at < b.created_at) { return -1 }
        if (a.created_at > b.created_at) { return 1 }
        return 0
      })
    } else if (this.currentSortKey === 'category') {
      sorted.sort((a: ScheduleItem, b: ScheduleItem): number => {
        if (a.category < b.category) { return -1 }
        if (a.category > b.category) { return 1 }
        return 0
      })
    }
    this.scheduleList = sorted
  }

  private selectDay(index: number): void {
    this.selectedDayIndex = this.weekDates[index].dayIndex
    this.filterAndSort()
  }

  private selectSort(key: string): void {
    this.currentSortKey = key
    this.showSortPanel = false
    this.filterAndSort()
  }

  private filterAndSort(): void {
    let dayNum: number = this.selectedDayIndex > 0 ? this.selectedDayIndex : 7
    let dayStr: string = dayNum.toString()
    let filtered: ScheduleItem[] = []
    for (let i: number = 0; i < this.allSchedules.length; i++) {
      let item: ScheduleItem = this.allSchedules[i]
      if (item.repeat_days !== null && item.repeat_days !== undefined) {
        let parts: string[] = item.repeat_days.split(',')
        for (let j: number = 0; j < parts.length; j++) {
          if (parts[j].trim() === dayStr) {
            filtered.push(item)
            break
          }
        }
      }
    }
    this.sortAndSet(filtered)
  }

  private getSelectedDayLabel(): string {
    for (let i: number = 0; i < this.weekDates.length; i++) {
      if (this.weekDates[i].dayIndex === this.selectedDayIndex) {
        if (this.weekDates[i].isToday) {
          return '\u4ECA\u5929'
        }
        return '\u5468' + this.weekDates[i].dayLabel
      }
    }
    return '\u4ECA\u5929'
  }

  build() {
    Stack() {
      Column() {
        this.HeaderBuilder()
        this.CalendarStripBuilder()

        Stack({ alignContent: Alignment.BottomEnd }) {
          Scroll() {
            if (this.scheduleList.length === 0 && !this.isLoading) {
              Column() {
                this.EmptyStateBuilder()
              }
              .width('100%')
              .layoutWeight(1)
              .justifyContent(FlexAlign.Center)
            } else {
              Column({ space: 12 }) {
                ForEach(this.scheduleList, (item: ScheduleItem) => {
                  this.ScheduleCardBuilder(item)
                }, (item: ScheduleItem) => item.id.toString())
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 12, bottom: 80 })
            }
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)

          this.FABBuilder()
        }
        .layoutWeight(1)

        this.BottomNavBarBuilder()
      }
      .width('100%')
      .height('100%')

      this.SortPanelOverlay()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BG)
  }

  @Builder
  HeaderBuilder() {
    Row() {
      Text('\u4F18\u5F8B')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.PRIMARY)

      Text(this.currentMonthYear)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.TEXT_PRIMARY)
        .margin({ left: 12 })

      Blank()

      Text('\u2630')
        .fontSize(20)
        .fontColor(Theme.TEXT_SECONDARY)
        .width(40)
        .height(40)
        .textAlign(TextAlign.Center)
        .borderRadius(20)
        .backgroundColor(Theme.SURFACE)
        .onClick(() => {
          this.showSortPanel = true
        })
    }
    .width('100%')
    .padding({ left: 20, right: 16, top: 12, bottom: 8 })
    .backgroundColor(Theme.CARD)
  }

  @Builder
  CalendarStripBuilder() {
    Row() {
      ForEach(this.weekDates, (item: WeekDateItem, index: number) => {
        Column({ space: 4 }) {
          Text(item.dayLabel)
            .fontSize(12)
            .fontColor(item.dayIndex === this.selectedDayIndex ? Theme.PRIMARY : Theme.TEXT_LIGHT)

          Column() {
            Text(item.isToday ? '\u4ECA' : item.dateNum)
              .fontSize(item.isToday ? 11 : 14)
              .fontColor(item.dayIndex === this.selectedDayIndex ? Color.White : Theme.TEXT_PRIMARY)
              .fontWeight(item.dayIndex === this.selectedDayIndex ? FontWeight.Bold : FontWeight.Normal)
          }
          .width(36)
          .height(36)
          .borderRadius(18)
          .backgroundColor(item.dayIndex === this.selectedDayIndex ? Theme.PRIMARY : 'transparent')
          .justifyContent(FlexAlign.Center)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
        .onClick(() => {
          this.selectDay(index)
        })
      }, (item: WeekDateItem, index: number) => index.toString())
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 12 })
    .backgroundColor(Theme.CARD)
    .shadow({ radius: 4, color: Theme.SHADOW, offsetY: 2 })
  }

  @Builder
  ScheduleCardBuilder(item: ScheduleItem) {
    Row() {
      Column()
        .width(4)
        .height(48)
        .borderRadius(2)
        .backgroundColor(item.color)

      Column({ space: 6 }) {
        Row() {
          Text(item.title)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(Theme.TEXT_PRIMARY)
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(Theme.getCategoryName(item.category))
            .fontSize(11)
            .fontColor(item.color)
            .backgroundColor(item.color + '18')
            .borderRadius(4)
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
        }
        .width('100%')

        Text(item.start_time + ' - ' + item.end_time)
          .fontSize(13)
          .fontColor(Theme.TEXT_SECONDARY)

        if (item.reminder_minutes !== null && item.reminder_minutes !== undefined && item.reminder_minutes > 0) {
          Text('\u63D0\u524D' + item.reminder_minutes.toString() + '\u5206\u949F\u63D0\u9192')
            .fontSize(11)
            .fontColor(Theme.WARNING)
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Theme.CARD)
    .borderRadius(12)
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      const routerParams: Record<string, Object> = {}
      routerParams['id'] = item.id
      router.pushUrl({
        url: 'pages/AddSchedulePage',
        params: routerParams
      })
    })
    .shadow({ radius: 8, color: Theme.SHADOW, offsetX: 0, offsetY: 2 })
    .animation({ duration: 150 })
  }

  @Builder
  EmptyStateBuilder() {
    Column({ space: 16 }) {
      Text('\u2600')
        .fontSize(64)

      Text(this.getSelectedDayLabel() + '\u8FD8\u6CA1\u6709\u65E5\u7A0B\u5B89\u6392')
        .fontSize(18)
        .fontColor(Theme.TEXT_SECONDARY)
        .fontWeight(FontWeight.Medium)

      Text('\u70B9\u51FB\u53F3\u4E0B\u89D2\u6309\u94AE\u6DFB\u52A0\u65B0\u65E5\u7A0B')
        .fontSize(14)
        .fontColor(Theme.TEXT_LIGHT)
    }
    .width('100%')
    .padding({ top: 40, bottom: 40 })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  FABBuilder() {
    Button() {
      Text('+')
        .fontSize(28)
        .fontColor(Color.White)
        .fontWeight(FontWeight.Bold)
    }
    .width(56)
    .height(56)
    .borderRadius(28)
    .backgroundColor(Theme.PRIMARY)
    .shadow({ radius: 8, color: Theme.PRIMARY + '50', offsetY: 4 })
    .margin({ right: 20, bottom: 20 })
    .stateEffect(true)
    .onClick(() => {
      router.pushUrl({ url: 'pages/AddSchedulePage' })
    })
  }

  @Builder
  SortPanelOverlay() {
    if (this.showSortPanel) {
      Column() {
        Blank()
          .onClick(() => {
            this.showSortPanel = false
          })

        Column() {
          ForEach(this.sortOptions, (opt: SortOptionItem) => {
            Row() {
              Text(opt.label)
                .fontSize(15)
                .fontColor(Theme.TEXT_PRIMARY)
                .layoutWeight(1)

              if (this.currentSortKey === opt.key) {
                Text('\u2713')
                  .fontSize(16)
                  .fontColor(Theme.PRIMARY)
                  .fontWeight(FontWeight.Bold)
              }
            }
            .width('100%')
            .height(48)
            .padding({ left: 24, right: 24 })
            .alignItems(VerticalAlign.Center)
            .onClick(() => {
              this.selectSort(opt.key)
            })
          }, (opt: SortOptionItem, index: number) => opt.key)

          Divider()
            .color(Theme.DIVIDER)
            .margin({ left: 24, right: 24, top: 4, bottom: 4 })

          Text('\u53D6\u6D88')
            .fontSize(15)
            .fontColor(Theme.TEXT_SECONDARY)
            .width('100%')
            .height(48)
            .textAlign(TextAlign.Center)
            .onClick(() => {
              this.showSortPanel = false
            })
        }
        .width('100%')
        .padding({ top: 8, bottom: 16 })
        .backgroundColor(Theme.CARD)
        .borderRadius({ topLeft: 16, topRight: 16 })
        .shadow({ radius: 12, color: Theme.SHADOW, offsetY: -4 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#4D000000')
    }
  }

  @Builder
  BottomNavBarBuilder() {
    Row() {
      ForEach(this.tabs, (tab: TabInfo) => {
        Column({ space: 2 }) {
          Text(this.currentTab === tab.index ? tab.activeIcon : tab.icon)
            .fontSize(22)
            .fontColor(this.currentTab === tab.index ? Theme.PRIMARY : Theme.TEXT_LIGHT)

          Text(tab.title)
            .fontSize(11)
            .fontColor(this.currentTab === tab.index ? Theme.PRIMARY : Theme.TEXT_LIGHT)
            .fontWeight(this.currentTab === tab.index ? FontWeight.Medium : FontWeight.Normal)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
        .padding({ top: 8, bottom: 8 })
        .onClick(() => {
          if (this.currentTab !== tab.index) {
            router.replaceUrl({ url: tab.url })
          }
        })
      }, (tab: TabInfo) => tab.index.toString())
    }
    .width('100%')
    .height(56)
    .backgroundColor(Theme.CARD)
    .border({
      width: { top: 1 },
      color: { top: Theme.DIVIDER }
    })
  }
}
