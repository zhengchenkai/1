/**
 * HTTP请求工具类
 * - 自动从 AppStorage 读取 Bearer token
 * - 统一处理 JSON 解析
 * - 必须设置 expectDataType 防止 ArrayBuffer 问题
 */
import { http } from '@kit.NetworkKit';
import { ApiConfig } from './ApiConfig';

export class HttpUtils {
  /**
   * 获取请求头，自动附加 Bearer token
   */
  private static getHeaders(): Record<string, string> {
    const headers: Record<string, string> = { 'Content-Type': 'application/json' };
    const token: string = AppStorage.get<string>('authToken') || '';
    if (token.length > 0) {
      headers['Authorization'] = 'Bearer ' + token;
    }
    return headers;
  }

  /**
   * GET 请求
   * @param path API路径，如 /schedules
   * @returns 解析后的JSON对象
   */
  static async get(path: string): Promise<Record<string, Object>> {
    const httpRequest: http.HttpRequest = http.createHttp();
    try {
      const response: http.HttpResponse = await httpRequest.request(ApiConfig.BASE_URL + path, {
        method: http.RequestMethod.GET,
        header: HttpUtils.getHeaders(),
        expectDataType: http.HttpDataType.STRING
      });
      const result: Record<string, Object> = JSON.parse(response.result as string) as Record<string, Object>;
      return result;
    } catch (err) {
      const error: Error = err as Error;
      console.error('[HttpUtils] GET ' + path + ' 失败: ' + error.message);
      throw error;
    } finally {
      httpRequest.destroy();
    }
  }

  /**
   * POST 请求
   * @param path API路径
   * @param body 请求体对象
   * @returns 解析后的JSON对象
   */
  static async post(path: string, body: Record<string, Object | null>): Promise<Record<string, Object>> {
    const httpRequest: http.HttpRequest = http.createHttp();
    try {
      const response: http.HttpResponse = await httpRequest.request(ApiConfig.BASE_URL + path, {
        method: http.RequestMethod.POST,
        header: HttpUtils.getHeaders(),
        extraData: JSON.stringify(body),
        expectDataType: http.HttpDataType.STRING
      });
      const result: Record<string, Object> = JSON.parse(response.result as string) as Record<string, Object>;
      return result;
    } catch (err) {
      const error: Error = err as Error;
      console.error('[HttpUtils] POST ' + path + ' 失败: ' + error.message);
      throw error;
    } finally {
      httpRequest.destroy();
    }
  }

  /**
   * PUT 请求
   */
  static async put(path: string, body: Record<string, Object | null>): Promise<Record<string, Object>> {
    const httpRequest: http.HttpRequest = http.createHttp();
    try {
      const response: http.HttpResponse = await httpRequest.request(ApiConfig.BASE_URL + path, {
        method: http.RequestMethod.PUT,
        header: HttpUtils.getHeaders(),
        extraData: JSON.stringify(body),
        expectDataType: http.HttpDataType.STRING
      });
      const result: Record<string, Object> = JSON.parse(response.result as string) as Record<string, Object>;
      return result;
    } catch (err) {
      const error: Error = err as Error;
      console.error('[HttpUtils] PUT ' + path + ' 失败: ' + error.message);
      throw error;
    } finally {
      httpRequest.destroy();
    }
  }

  /**
   * DELETE 请求
   */
  static async delete(path: string): Promise<Record<string, Object>> {
    const httpRequest: http.HttpRequest = http.createHttp();
    try {
      const response: http.HttpResponse = await httpRequest.request(ApiConfig.BASE_URL + path, {
        method: http.RequestMethod.DELETE,
        header: HttpUtils.getHeaders(),
        expectDataType: http.HttpDataType.STRING
      });
      const result: Record<string, Object> = JSON.parse(response.result as string) as Record<string, Object>;
      return result;
    } catch (err) {
      const error: Error = err as Error;
      console.error('[HttpUtils] DELETE ' + path + ' 失败: ' + error.message);
      throw error;
    } finally {
      httpRequest.destroy();
    }
  }
}
