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

@Entry
@Component
struct SchedulePage {
  @State scheduleList: ScheduleItem[] = []
  @State isLoading: boolean = false
  @State currentDate: string = ''
  @State currentTab: number = 0

  private tabs: TabInfo[] = [
    { icon: '\u25A1', activeIcon: '\u25A0', title: '\u65E5\u7A0B', url: 'pages/SchedulePage', index: 0 },
    { icon: '\u25CB', activeIcon: '\u25CF', title: '\u6253\u5361', url: 'pages/CheckinPage', index: 1 },
    { icon: '\u25B3', activeIcon: '\u25B2', title: '\u7EDF\u8BA1', url: 'pages/StatsPage', index: 2 },
    { icon: '\u25CB', activeIcon: '\u25CF', title: '\u6211\u7684', url: 'pages/ProfilePage', index: 3 }
  ]

  aboutToAppear(): void {
    this.updateDate()
    this.loadSchedules()
  }

  onPageShow(): void {
    this.loadSchedules()
  }

  private updateDate(): void {
    let now: Date = new Date()
    let year: number = now.getFullYear()
    let month: number = now.getMonth() + 1
    let day: number = now.getDate()
    let weekDays: string[] = ['\u65E5', '\u4E00', '\u4E8C', '\u4E09', '\u56DB', '\u4E94', '\u516D']
    let weekDay: string = weekDays[now.getDay()]
    this.currentDate = `${year}\u5E74${month}\u6708${day}\u65E5 \u5468${weekDay}`
  }

  async loadSchedules(): Promise<void> {
    this.isLoading = true
    try {
      let response: Record<string, Object> = await HttpUtils.get('/schedules') as Record<string, Object>
      let allSchedules: ScheduleItem[] = response['data'] as ScheduleItem[]
      let now: Date = new Date()
      let dayOfWeek: number = now.getDay() > 0 ? now.getDay() : 7
      let todayStr: string = dayOfWeek.toString()
      let todayList: ScheduleItem[] = []
      for (let i: number = 0; i < allSchedules.length; i++) {
        let item: ScheduleItem = allSchedules[i]
        if (item.repeat_days !== null && item.repeat_days !== undefined) {
          let daysArr: string[] = item.repeat_days.split(',')
          let dayNums: number[] = []
          for (let j: number = 0; j < daysArr.length; j++) {
            let trimmed: string = daysArr[j].trim()
            if (trimmed.length > 0) {
              dayNums.push(parseInt(trimmed))
            }
          }
          if (dayNums.indexOf(dayOfWeek) >= 0) {
            todayList.push(item)
          }
        }
      }
      todayList.sort((a: ScheduleItem, b: ScheduleItem): number => {
        if (a.start_time < b.start_time) {
          return -1
        }
        if (a.start_time > b.start_time) {
          return 1
        }
        return 0
      })
      this.scheduleList = todayList
    } catch (e) {
      promptAction.showToast({ message: '\u52A0\u8F7D\u5931\u8D25\uFF0C\u8BF7\u7A0D\u540E\u91CD\u8BD5' })
    }
    this.isLoading = false
  }

  build() {
    Column() {
      this.HeaderBuilder()

      Stack({ alignContent: Alignment.BottomEnd }) {
        Scroll() {
          if (this.scheduleList.length === 0 && !this.isLoading) {
            this.EmptyStateBuilder()
          } else {
            Column({ space: 12 }) {
              ForEach(this.scheduleList, (item: ScheduleItem) => {
                this.ScheduleCardBuilder(item)
              }, (item: ScheduleItem) => item.id.toString())
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 12, bottom: 90 })
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
    .backgroundColor(Theme.BG)
  }

  @Builder
  HeaderBuilder() {
    Column({ space: 4 }) {
      Row() {
        Text('\u4F18\u5F8B')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.PRIMARY)
        Blank()
        Text(this.currentDate)
          .fontSize(14)
          .fontColor(Theme.TEXT_SECONDARY)
      }
      .width('100%')

      Text('\u4ECA\u65E5\u65E5\u7A0B')
        .fontSize(14)
        .fontColor(Theme.TEXT_LIGHT)
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 16, bottom: 12 })
    .backgroundColor(Theme.CARD)
    .shadow({ radius: 4, color: Theme.SHADOW, offsetY: 2 })
  }

  @Builder
  ScheduleCardBuilder(item: ScheduleItem) {
    Row() {
      Column()
        .width(4)
        .height('100%')
        .backgroundColor(item.color)
        .borderRadius({ topLeft: 12, bottomLeft: 12 })

      Column({ space: 8 }) {
        Row() {
          Text(item.title)
            .fontSize(16)
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
      .padding({ left: 12, right: 16, top: 14, bottom: 14 })
    }
    .width('100%')
    .backgroundColor(Theme.CARD)
    .borderRadius(12)
    .clip(true)
    .onClick(() => {
      const routerParams: Record<string, Object> = {};
      routerParams['id'] = item.id;
      router.pushUrl({
        url: 'pages/AddSchedulePage',
        params: routerParams
      })
    })
    .shadow({ radius: 4, color: Theme.SHADOW, offsetY: 2 })
    .animation({ duration: 150 })
  }

  @Builder
  EmptyStateBuilder() {
    Column({ space: 16 }) {
      Text('\u2600')
        .fontSize(64)
        .margin({ top: 80 })

      Text('\u4ECA\u5929\u8FD8\u6CA1\u6709\u65E5\u7A0B\u5B89\u6392')
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
