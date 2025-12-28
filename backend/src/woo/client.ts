import { config } from '../config';

export type WooOrderItem = {
  id: number;
  name: string;
  sku: string | null;
  quantity: number;
  total: string;
};

export type WooOrder = {
  id: number;
  number: string;
  status: string;
  currency: string;
  total: string;
  customer_note?: string | null;
  payment_method?: string | null;
  billing?: {
    first_name?: string;
    last_name?: string;
    email?: string;
    city?: string;
  };
  shipping?: {
    city?: string;
  };
  line_items?: WooOrderItem[];
  date_created?: string;
  date_modified?: string;
};

export class WooClient {
  constructor(
    private readonly storeUrl: string,
    private readonly consumerKey: string,
    private readonly consumerSecret: string,
    private readonly apiVersion = config.wooApiVersion,
  ) {}

  private buildUrl(path: string, params?: Record<string, string | number | undefined | string[]>) {
    const url = new URL(
      `/wp-json/${this.apiVersion}/${path.replace(/^\//, '')}`,
      this.storeUrl.endsWith('/') ? this.storeUrl : `${this.storeUrl}/`,
    );
    url.searchParams.append('consumer_key', this.consumerKey);
    url.searchParams.append('consumer_secret', this.consumerSecret);
    if (params) {
      Object.entries(params).forEach(([key, value]) => {
        if (value === undefined) return;
        if (Array.isArray(value)) {
          value.forEach((v) => url.searchParams.append(key, v));
        } else {
          url.searchParams.append(key, String(value));
        }
      });
    }
    return url;
  }

  private async get<T>(path: string, params?: Record<string, any>): Promise<T> {
    const url = this.buildUrl(path, params);
    const res = await fetch(url, { headers: { Accept: 'application/json' } });
    if (!res.ok) {
      const text = await res.text();
      throw new Error(`WooCommerce request failed (${res.status}): ${text}`);
    }
    return (await res.json()) as T;
  }

  async fetchOrder(id: number) {
    return this.get<WooOrder>(`orders/${id}`);
  }

  async listOrders(params: {
    page?: number;
    per_page?: number;
    status?: string[];
    after?: string;
    search?: string;
    orderby?: string;
    order?: string;
  }) {
    return this.get<WooOrder[]>('orders', params);
  }

  async testConnection() {
    await this.listOrders({ per_page: 1, page: 1 });
    return true;
  }
}
