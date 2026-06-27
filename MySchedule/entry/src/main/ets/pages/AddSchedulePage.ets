import { router } from '@kit.ArkUI'
import { promptAction } from '@kit.ArkUI'
import { Theme } from '../common/Theme'
import { HttpUtils } from '../common/HttpUtils'
import { ScheduleItem } from '../model/Models'

interface CategoryDef {
  key: string
  name: string
}

interface ReminderOption {
  label: string
  minutes: number
}

@Entry
@Component
struct AddSchedulePage {
  @State isEditMode: boolean = false
  @State scheduleId: number = 0
  @State title: string = ''
  @State startTime: string = ''
  @State endTime: string = ''
  @State category: string = 'study'
  @State color: string = ''
  @State reminderMinutes: number = 0
  @State repeatDays: string = ''
  @State startHour: number = 0
  @State startMinute: number = 0
  @State endHour: number = 0
  @State endMinute: number = 0

  private categories: CategoryDef[] = [
    { key: 'wake', name: '\u8D77\u5E8A' },
    { key: 'study', name: '\u5B66\u4E60' },
    { key: 'nap', name: '\u5348\u4F11' },
    { key: 'exercise', name: '\u8FD0\u52A8' },
    { key: 'sleep', name: '\u7761\u7720' },
    { key: 'other', name: '\u5176\u4ED6' }
  ]

  private reminderOptions: ReminderOption[] = [
    { label: '\u4E0D\u63D0\u9192', minutes: 0 },
    { label: '5\u5206\u949F', minutes: 5 },
    { label: '10\u5206\u949F', minutes: 10 },
    { label: '15\u5206\u949F', minutes: 15 },
    { label: '30\u5206\u949F', minutes: 30 }
  ]

  private dayLabels: string[] = ['\u4E00', '\u4E8C', '\u4E09', '\u56DB', '\u4E94', '\u516D', '\u65E5']

  aboutToAppear(): void {
    this.color = Theme.getCategoryColor('study')
    let now: Date = new Date()
    this.startHour = now.getHours()
    this.startMinute = now.getMinutes()
    this.startTime = this.formatTime(this.startHour, this.startMinute)
    let endH: number = this.startHour + 1
    if (endH >= 24) {
      endH = 23
    }
    this.endHour = endH
    this.endMinute = this.startMinute
    this.endTime = this.formatTime(this.endHour, this.endMinute)
    let params: Record<string, Object> = router.getParams() as Record<string, Object>
    if (params !== null && params !== undefined && params['id'] !== undefined) {
      let receivedId: number = params['id'] as number
      if (receivedId > 0) {
        this.scheduleId = receivedId
        this.isEditMode = true
        this.loadSchedule()
      }
    }
  }

  async loadSchedule(): Promise<void> {
    try {
      let response: Record<string, Object> =
        await HttpUtils.get('/schedules/' + this.scheduleId.toString()) as Record<string, Object>
      let item: ScheduleItem = response['data'] as ScheduleItem
      this.title = item.title
      this.category = item.category
      this.color = item.color
      this.startTime = item.start_time.length >= 5 ? item.start_time.substring(0, 5) : item.start_time
      this.endTime = item.end_time.length >= 5 ? item.end_time.substring(0, 5) : item.end_time
      this.reminderMinutes = item.reminder_minutes !== null && item.reminder_minutes !== undefined
        ? item.reminder_minutes : 0
      this.repeatDays = item.repeat_days !== null && item.repeat_days !== undefined
        ? item.repeat_days : ''

      let startParts: string[] = item.start_time.split(':')
      this.startHour = parseInt(startParts[0])
      this.startMinute = parseInt(startParts[1])

      let endParts: string[] = item.end_time.split(':')
      this.endHour = parseInt(endParts[0])
      this.endMinute = parseInt(endParts[1])
    } catch (e) {
      promptAction.showToast({ message: '\u52A0\u8F7D\u65E5\u7A0B\u5931\u8D25' })
    }
  }

  private toggleDay(day: number): void {
    let dayStr: string = day.toString()
    if (this.repeatDays.length === 0) {
      this.repeatDays = dayStr
      return
    }
    let parts: string[] = this.repeatDays.split(',')
    let nums: number[] = []
    for (let i: number = 0; i < parts.length; i++) {
      let trimmed: string = parts[i].trim()
      if (trimmed.length > 0) {
        nums.push(parseInt(trimmed))
      }
    }
    let idx: number = nums.indexOf(day)
    if (idx >= 0) {
      let filtered: number[] = []
      for (let i: number = 0; i < nums.length; i++) {
        if (nums[i] !== day) {
          filtered.push(nums[i])
        }
      }
      this.repeatDays = filtered.join(',')
    } else {
      nums.push(day)
      nums.sort((a: number, b: number): number => a - b)
      this.repeatDays = nums.join(',')
    }
  }

  private isDaySelected(day: number): boolean {
    if (this.repeatDays.length === 0) {
      return false
    }
    let parts: string[] = this.repeatDays.split(',')
    let dayStr: string = day.toString()
    for (let i: number = 0; i < parts.length; i++) {
      if (parts[i].trim() === dayStr) {
        return true
      }
    }
    return false
  }

  private formatTime(hour: number, minute: number): string {
    let h: string = hour < 10 ? '0' + hour.toString() : hour.toString()
    let m: string = minute < 10 ? '0' + minute.toString() : minute.toString()
    return h + ':' + m
  }

  private selectCategory(cat: CategoryDef): void {
    this.category = cat.key
    this.color = Theme.getCategoryColor(cat.key)
  }

  private selectReminder(opt: ReminderOption): void {
    this.reminderMinutes = opt.minutes
  }

  private openStartTimePicker(): void {
    TimePickerDialog.show({
      selected: new Date('2000-01-01T' + this.formatTime(this.startHour, this.startMinute)),
      useMilitaryTime: true,
      onAccept: (result: TimePickerResult): void => {
        this.startHour = result.hour
        this.startMinute = result.minute
        this.startTime = this.formatTime(result.hour, result.minute)
      }
    })
  }

  private openEndTimePicker(): void {
    TimePickerDialog.show({
      selected: new Date('2000-01-01T' + this.formatTime(this.endHour, this.endMinute)),
      useMilitaryTime: true,
      onAccept: (result: TimePickerResult): void => {
        this.endHour = result.hour
        this.endMinute = result.minute
        this.endTime = this.formatTime(result.hour, result.minute)
      }
    })
  }

  async saveSchedule(): Promise<void> {
    if (this.title.length === 0) {
      promptAction.showToast({ message: '\u8BF7\u8F93\u5165\u65E5\u7A0B\u6807\u9898' })
      return
    }
    if (this.startTime >= this.endTime) {
      promptAction.showToast({ message: '\u7ED3\u675F\u65F6\u95F4\u5FC5\u987B\u665A\u4E8E\u5F00\u59CB\u65F6\u95F4' })
      return
    }
    if (this.repeatDays.length === 0) {
      promptAction.showDialog({
        title: '\u672A\u9009\u62E9\u91CD\u590D\u65E5\u671F',
        message: '\u672A\u52FE\u9009\u4EFB\u4F55\u65E5\u671F\uFF0C\u5C06\u9ED8\u8BA4\u4E3A\u6BCF\u5929\u91CD\u590D\u3002\u662F\u5426\u7EE7\u7EED\uFF1F',
        buttons: [
          { text: '\u53D6\u6D88', color: Theme.TEXT_SECONDARY },
          { text: '\u7EE7\u7EED', color: Theme.PRIMARY }
        ]
      }).then((result: promptAction.ShowDialogSuccessResponse) => {
        if (result.index === 1) {
          this.performSave()
        }
      })
      return
    }
    this.performSave()
  }

  async performSave(): Promise<void> {
    const body: Record<string, Object | null> = {};
    body['title'] = this.title;
    body['start_time'] = this.startTime;
    body['end_time'] = this.endTime;
    body['category'] = this.category;
    body['color'] = this.color;
    body['reminder_minutes'] = this.reminderMinutes;
    body['repeat_days'] = this.repeatDays.length > 0 ? this.repeatDays : null;
    try {
      if (this.isEditMode) {
        await HttpUtils.put('/schedules/' + this.scheduleId.toString(), body)
      } else {
        await HttpUtils.post('/schedules', body)
      }
      promptAction.showToast({ message: '\u4FDD\u5B58\u6210\u529F' })
      router.back()
    } catch (e) {
      promptAction.showToast({ message: '\u4FDD\u5B58\u5931\u8D25\uFF0C\u8BF7\u91CD\u8BD5' })
    }
  }

  deleteSchedule(): void {
    promptAction.showDialog({
      title: '\u786E\u8BA4\u5220\u9664',
      message: '\u786E\u5B9A\u8981\u5220\u9664\u8FD9\u6761\u65E5\u7A0B\u5417\uFF1F\u5220\u9664\u540E\u65E0\u6CD5\u6062\u590D\u3002',
      buttons: [
        { text: '\u53D6\u6D88', color: Theme.TEXT_SECONDARY },
        { text: '\u5220\u9664', color: Theme.DANGER }
      ]
    }).then((result: promptAction.ShowDialogSuccessResponse) => {
      if (result.index === 1) {
        this.performDelete()
      }
    })
  }

  async performDelete(): Promise<void> {
    try {
      await HttpUtils.delete('/schedules/' + this.scheduleId.toString())
      promptAction.showToast({ message: '\u5220\u9664\u6210\u529F' })
      router.back()
    } catch (e) {
      promptAction.showToast({ message: '\u5220\u9664\u5931\u8D25\uFF0C\u8BF7\u91CD\u8BD5' })
    }
  }

  build() {
    Column() {
      this.HeaderBarBuilder()

      Scroll() {
        Column({ space: 24 }) {
          this.TitleInputBuilder()
          this.CategorySelectorBuilder()
          this.TimeSelectorBuilder()
          this.RepeatDaysBuilder()
          this.ReminderSelectorBuilder()
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 20, bottom: 20 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)

      this.ActionButtonsBuilder()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BG)
  }

  @Builder
  HeaderBarBuilder() {
    Row() {
      Text('\u2190')
        .fontSize(24)
        .fontColor(Theme.TEXT_PRIMARY)
        .width(40)
        .height(40)
        .textAlign(TextAlign.Center)
        .onClick(() => {
          router.back()
        })

      Text(this.isEditMode ? '\u7F16\u8F91\u65E5\u7A0B' : '\u65B0\u5EFA\u65E5\u7A0B')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.TEXT_PRIMARY)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      Column()
        .width(40)
    }
    .width('100%')
    .height(56)
    .padding({ left: 12, right: 12 })
    .backgroundColor(Theme.CARD)
    .shadow({ radius: 2, color: Theme.SHADOW, offsetY: 1 })
  }

  @Builder
  TitleInputBuilder() {
    Column({ space: 8 }) {
      Text('\u65E5\u7A0B\u6807\u9898')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.TEXT_PRIMARY)

      TextInput({ text: this.title, placeholder: '\u8BF7\u8F93\u5165\u65E5\u7A0B\u6807\u9898' })
        .onChange((value: string) => {
          this.title = value
        })
        .fontSize(16)
        .fontColor(Theme.TEXT_PRIMARY)
        .placeholderColor(Theme.TEXT_LIGHT)
        .backgroundColor(Theme.CARD)
        .borderRadius(10)
        .height(48)
        .padding({ left: 16, right: 16 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  CategorySelectorBuilder() {
    Column({ space: 10 }) {
      Text('\u5206\u7C7B')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.TEXT_PRIMARY)

      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.categories, (cat: CategoryDef) => {
          Text(cat.name)
            .fontSize(13)
            .fontColor(this.category === cat.key ? Color.White : Theme.TEXT_SECONDARY)
            .backgroundColor(this.category === cat.key ? Theme.PRIMARY : Theme.CARD)
            .borderRadius(20)
            .padding({ left: 18, right: 18, top: 8, bottom: 8 })
            .margin({ right: 8, bottom: 8 })
            .border({
              width: { top: 1, bottom: 1, left: 1, right: 1 },
              color: {
                top: this.category === cat.key ? Theme.PRIMARY : Theme.DIVIDER,
                bottom: this.category === cat.key ? Theme.PRIMARY : Theme.DIVIDER,
                left: this.category === cat.key ? Theme.PRIMARY : Theme.DIVIDER,
                right: this.category === cat.key ? Theme.PRIMARY : Theme.DIVIDER
              }
            })
            .onClick(() => {
              this.selectCategory(cat)
            })
        }, (cat: CategoryDef, index: number) => cat.key)
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  TimeSelectorBuilder() {
    Column({ space: 10 }) {
      Text('\u65F6\u95F4')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.TEXT_PRIMARY)

      Row({ space: 12 }) {
        Column({ space: 4 }) {
          Text('\u5F00\u59CB\u65F6\u95F4')
            .fontSize(12)
            .fontColor(Theme.TEXT_SECONDARY)

          Text(this.startTime)
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.PRIMARY)
            .width('100%')
            .height(48)
            .textAlign(TextAlign.Center)
            .backgroundColor(Theme.PRIMARY_BG)
            .borderRadius(10)
            .onClick(() => {
              this.openStartTimePicker()
            })
        }
        .layoutWeight(1)

        Text('\u2192')
          .fontSize(22)
          .fontColor(Theme.TEXT_LIGHT)
          .margin({ top: 18 })

        Column({ space: 4 }) {
          Text('\u7ED3\u675F\u65F6\u95F4')
            .fontSize(12)
            .fontColor(Theme.TEXT_SECONDARY)

          Text(this.endTime)
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.PRIMARY)
            .width('100%')
            .height(48)
            .textAlign(TextAlign.Center)
            .backgroundColor(Theme.PRIMARY_BG)
            .borderRadius(10)
            .onClick(() => {
              this.openEndTimePicker()
            })
        }
        .layoutWeight(1)
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  RepeatDaysBuilder() {
    Column({ space: 10 }) {
      Text('\u91CD\u590D')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.TEXT_PRIMARY)

      Row({ space: 8 }) {
        ForEach(this.dayLabels, (day: string, index: number) => {
          Text(day)
            .fontSize(14)
            .fontWeight(this.isDaySelected(index + 1) ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.isDaySelected(index + 1) ? Color.White : Theme.TEXT_SECONDARY)
            .width(40)
            .height(40)
            .textAlign(TextAlign.Center)
            .borderRadius(20)
            .backgroundColor(this.isDaySelected(index + 1) ? Theme.PRIMARY : Theme.CARD)
            .border({
              width: { top: 1, bottom: 1, left: 1, right: 1 },
              color: {
                top: this.isDaySelected(index + 1) ? Theme.PRIMARY : Theme.DIVIDER,
                bottom: this.isDaySelected(index + 1) ? Theme.PRIMARY : Theme.DIVIDER,
                left: this.isDaySelected(index + 1) ? Theme.PRIMARY : Theme.DIVIDER,
                right: this.isDaySelected(index + 1) ? Theme.PRIMARY : Theme.DIVIDER
              }
            })
            .onClick(() => {
              this.toggleDay(index + 1)
            })
        }, (day: string, index: number) => index.toString())
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ReminderSelectorBuilder() {
    Column({ space: 10 }) {
      Text('\u63D0\u9192')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.TEXT_PRIMARY)

      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.reminderOptions, (opt: ReminderOption) => {
          Text(opt.label)
            .fontSize(13)
            .fontColor(this.reminderMinutes === opt.minutes ? Color.White : Theme.TEXT_SECONDARY)
            .backgroundColor(this.reminderMinutes === opt.minutes
              ? Theme.PRIMARY
              : Theme.CARD)
            .borderRadius(16)
            .padding({ left: 16, right: 16, top: 8, bottom: 8 })
            .margin({ right: 8, bottom: 8 })
            .border({
              width: { top: 1, bottom: 1, left: 1, right: 1 },
              color: {
                top: this.reminderMinutes === opt.minutes ? Theme.PRIMARY : Theme.DIVIDER,
                bottom: this.reminderMinutes === opt.minutes ? Theme.PRIMARY : Theme.DIVIDER,
                left: this.reminderMinutes === opt.minutes ? Theme.PRIMARY : Theme.DIVIDER,
                right: this.reminderMinutes === opt.minutes ? Theme.PRIMARY : Theme.DIVIDER
              }
            })
            .onClick(() => {
              this.selectReminder(opt)
            })
        }, (opt: ReminderOption, index: number) => index.toString())
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ActionButtonsBuilder() {
    Column({ space: 12 }) {
      Button(this.isEditMode ? '\u4FDD\u5B58\u4FEE\u6539' : '\u4FDD\u5B58')
        .width('100%')
        .height(48)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .backgroundColor(Theme.PRIMARY)
        .borderRadius(12)
        .stateEffect(true)
        .onClick(() => {
          this.saveSchedule()
        })

      if (this.isEditMode) {
        Button('\u5220\u9664\u65E5\u7A0B')
          .width('100%')
          .height(48)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.DANGER)
          .backgroundColor(Color.Transparent)
          .borderRadius(12)
          .border({
            width: { top: 1, bottom: 1, left: 1, right: 1 },
            color: { top: Theme.DANGER, bottom: Theme.DANGER, left: Theme.DANGER, right: Theme.DANGER }
          })
          .stateEffect(true)
          .onClick(() => {
            this.deleteSchedule()
          })
      }
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 12, bottom: 24 })
    .backgroundColor(Theme.CARD)
    .shadow({ radius: 4, color: Theme.SHADOW, offsetY: -2 })
  }
}
