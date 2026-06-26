import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { Theme } from '../common/Theme';
import { HttpUtils } from '../common/HttpUtils';

@Entry
@Component
struct LoginPage {
  @State username: string = '';
  @State password: string = '';
  @State isLoading: boolean = false;

  build() {
    Scroll() {
      Column() {
        // ===== Header: App Branding =====
        Column() {
          Text('优律')
            .fontSize(52)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.PRIMARY)
            .letterSpacing(6)
            .margin({ top: 20 })

          Text('智能日程管理')
            .fontSize(15)
            .fontColor(Theme.TEXT_SECONDARY)
            .margin({ top: 8 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .padding({ top: 80, bottom: 40 })

        // ===== Login Card =====
        Column() {
          Text('欢迎回来')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT_PRIMARY)
            .margin({ bottom: 6 })

          Text('登录以继续管理您的日程')
            .fontSize(14)
            .fontColor(Theme.TEXT_SECONDARY)
            .margin({ bottom: 32 })

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
            .margin({ bottom: 20 })
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
            .margin({ bottom: 32 })
            .padding({ left: 16, right: 16 })

          // Login Button
          Button(this.isLoading ? '登录中...' : '登 录')
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
            .enabled(!this.isLoading && this.username.length > 0 && this.password.length > 0)
            .opacity(
              (!this.isLoading && this.username.length > 0 && this.password.length > 0) ? 1.0 : 0.5
            )
            .onClick((): void => {
              this.handleLogin();
            })

          // Register Link
          Row() {
            Text('还没有账号？')
              .fontSize(14)
              .fontColor(Theme.TEXT_SECONDARY)
            Text('立即注册')
              .fontSize(14)
              .fontColor(Theme.PRIMARY)
              .fontWeight(FontWeight.Medium)
              .onClick((): void => {
                router.pushUrl({ url: 'pages/RegisterPage' });
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

  private async handleLogin(): Promise<void> {
    if (this.isLoading) {
      return;
    }
    if (this.username.length === 0) {
      promptAction.showToast({ message: '请输入用户名', duration: 2000 });
      return;
    }
    if (this.password.length === 0) {
      promptAction.showToast({ message: '请输入密码', duration: 2000 });
      return;
    }

    this.isLoading = true;
    try {
      const res: Record<string, Object> = await HttpUtils.post('/auth/login', {
        'username': this.username,
        'password': this.password
      });
      // 后端直接返回 { token, username, nickname }，无 code 字段
      const token: string = (res['token'] as string) ?? '';
      if (token.length > 0) {
        AppStorage.setOrCreate<string>('authToken', token);
        AppStorage.setOrCreate<string>('authUsername', this.username);
        AppStorage.setOrCreate<string>('authNickname', (res['nickname'] as string) ?? this.username);
        AppStorage.setOrCreate<boolean>('isLoggedIn', true);
        promptAction.showToast({ message: '登录成功', duration: 1500 });
        router.replaceUrl({ url: 'pages/SchedulePage' });
      } else {
        const errMsg: string = (res['error'] as string) ?? '登录失败';
        promptAction.showToast({ message: errMsg, duration: 2000 });
      }
    } catch (err) {
      promptAction.showToast({ message: '网络错误，请检查网络连接', duration: 2000 });
    } finally {
      this.isLoading = false;
    }
  }
}
