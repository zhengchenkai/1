import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { Theme } from '../common/Theme';
import { HttpUtils } from '../common/HttpUtils';

@Entry
@Component
struct RegisterPage {
  @State username: string = '';
  @State nickname: string = '';
  @State password: string = '';
  @State confirmPassword: string = '';
  @State isLoading: boolean = false;

  build() {
    Scroll() {
      Column() {
        // ===== Header: Page Title =====
        Column() {
          Text('创建账号')
            .fontSize(36)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.PRIMARY)
            .letterSpacing(2)
            .margin({ top: 20 })

          Text('注册以开始管理您的日程')
            .fontSize(15)
            .fontColor(Theme.TEXT_SECONDARY)
            .margin({ top: 8 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .padding({ top: 60, bottom: 36 })

        // ===== Register Card =====
        Column() {
          // Username Input
          Text('用户名')
            .fontSize(13)
            .fontColor(Theme.TEXT_SECONDARY)
            .margin({ bottom: 8 })
            .alignSelf(ItemAlign.Start)

          TextInput({ placeholder: '请输入用户名', text: this.username })
            .type(InputType.Normal)
            .onChange((value: string): void => {
              this.username = value;
            })
            .height(48)
            .backgroundColor(Theme.BG)
            .borderRadius(12)
            .fontSize(16)
            .fontColor(Theme.TEXT_PRIMARY)
            .placeholderColor(Theme.TEXT_LIGHT)
            .margin({ bottom: 18 })
            .padding({ left: 16, right: 16 })

          // Nickname Input
          Text('昵称')
            .fontSize(13)
            .fontColor(Theme.TEXT_SECONDARY)
            .margin({ bottom: 8 })
            .alignSelf(ItemAlign.Start)

          TextInput({ placeholder: '请输入昵称', text: this.nickname })
            .type(InputType.Normal)
            .onChange((value: string): void => {
              this.nickname = value;
            })
            .height(48)
            .backgroundColor(Theme.BG)
            .borderRadius(12)
            .fontSize(16)
            .fontColor(Theme.TEXT_PRIMARY)
            .placeholderColor(Theme.TEXT_LIGHT)
            .margin({ bottom: 18 })
            .padding({ left: 16, right: 16 })

          // Password Input
          Text('密码')
            .fontSize(13)
            .fontColor(Theme.TEXT_SECONDARY)
            .margin({ bottom: 8 })
            .alignSelf(ItemAlign.Start)

          TextInput({ placeholder: '请输入密码', text: this.password })
            .type(InputType.Password)
            .onChange((value: string): void => {
              this.password = value;
            })
            .height(48)
            .backgroundColor(Theme.BG)
            .borderRadius(12)
            .fontSize(16)
            .fontColor(Theme.TEXT_PRIMARY)
            .placeholderColor(Theme.TEXT_LIGHT)
            .margin({ bottom: 18 })
            .padding({ left: 16, right: 16 })

          // Confirm Password Input
          Text('确认密码')
            .fontSize(13)
            .fontColor(Theme.TEXT_SECONDARY)
            .margin({ bottom: 8 })
            .alignSelf(ItemAlign.Start)

          TextInput({ placeholder: '请再次输入密码', text: this.confirmPassword })
            .type(InputType.Password)
            .onChange((value: string): void => {
              this.confirmPassword = value;
            })
            .height(48)
            .backgroundColor(Theme.BG)
            .borderRadius(12)
            .fontSize(16)
            .fontColor(Theme.TEXT_PRIMARY)
            .placeholderColor(Theme.TEXT_LIGHT)
            .margin({ bottom: 28 })
            .padding({ left: 16, right: 16 })

          // Register Button
          Button(this.isLoading ? '注册中...' : '注 册')
            .type(ButtonType.Normal)
            .width('100%')
            .height(50)
            .borderRadius(25)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .backgroundColor(this.isLoading ? Theme.PRIMARY_LIGHT : Theme.PRIMARY)
            .linearGradient({
              angle: 135,
              colors: [
                [Theme.PRIMARY, 0.0],
                [Theme.PRIMARY_DARK, 1.0]
              ]
            })
            .enabled(
              !this.isLoading
              && this.username.length > 0
              && this.nickname.length > 0
              && this.password.length > 0
              && this.confirmPassword.length > 0
            )
            .opacity(
              (!this.isLoading
                && this.username.length > 0
                && this.nickname.length > 0
                && this.password.length > 0
                && this.confirmPassword.length > 0) ? 1.0 : 0.5
            )
            .onClick((): void => {
              this.handleRegister();
            })

          // Back to Login Link
          Row() {
            Text('已有账号？')
              .fontSize(14)
              .fontColor(Theme.TEXT_SECONDARY)
            Text('返回登录')
              .fontSize(14)
              .fontColor(Theme.PRIMARY)
              .fontWeight(FontWeight.Medium)
              .onClick((): void => {
                router.back();
              })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .margin({ top: 24 })
        }
        .width('100%')
        .padding(28)
        .backgroundColor(Theme.CARD)
        .borderRadius(20)
        .margin({ left: 24, right: 24 })
        .shadow({
          radius: 24,
          color: '#1A6C5CE7',
          offsetX: 0,
          offsetY: 8
        })

        // Bottom spacer for scroll
        Blank().height(60)
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .backgroundColor(Theme.PRIMARY_BG)
  }

  private async handleRegister(): Promise<void> {
    if (this.isLoading) {
      return;
    }
    if (this.username.length === 0) {
      promptAction.showToast({ message: '请输入用户名', duration: 2000 });
      return;
    }
    if (this.nickname.length === 0) {
      promptAction.showToast({ message: '请输入昵称', duration: 2000 });
      return;
    }
    if (this.password.length === 0) {
      promptAction.showToast({ message: '请输入密码', duration: 2000 });
      return;
    }
    if (this.password.length < 6) {
      promptAction.showToast({ message: '密码长度不能少于6位', duration: 2000 });
      return;
    }
    if (this.password !== this.confirmPassword) {
      promptAction.showToast({ message: '两次输入的密码不一致', duration: 2000 });
      return;
    }

    this.isLoading = true;
    try {
      const res: Record<string, Object> = await HttpUtils.post('/auth/register', {
        'username': this.username,
        'nickname': this.nickname,
        'password': this.password
      });
      // 后端直接返回 { message, userId }，无 code 字段
      const errMsg: string = (res['error'] as string) ?? '';
      if (errMsg.length > 0) {
        promptAction.showToast({ message: errMsg, duration: 2000 });
      } else {
        const msg: string = (res['message'] as string) ?? '注册成功';
        promptAction.showToast({ message: msg + '，请登录', duration: 2000 });
        router.back();
      }
    } catch (err) {
      promptAction.showToast({ message: '网络错误，请检查网络连接', duration: 2000 });
    } finally {
      this.isLoading = false;
    }
  }
}
