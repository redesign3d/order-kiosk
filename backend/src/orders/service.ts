import { OrderStatus, Prisma } from '@prisma/client';
import { prisma } from '../db';
import { WooOrder, WooOrderItem } from '../woo/client';

const statusMap: Record<string, OrderStatus> = {
  pending: OrderStatus.PENDING,
  processing: OrderStatus.PROCESSING,
  completed: OrderStatus.COMPLETED,
  cancelled: OrderStatus.CANCELLED,
  refunded: OrderStatus.REFUNDED,
  'checkout-draft': OrderStatus.DRAFT,
};

const toStatus = (value: string): OrderStatus =>
  statusMap[value] ?? OrderStatus.PENDING;

const mapItems = (items: WooOrderItem[]) =>
  items.map((item) => ({
    name: item.name,
    sku: item.sku ?? undefined,
    quantity: item.quantity,
    total: new Prisma.Decimal(item.total ?? '0'),
  }));

const mapWooOrder = (order: WooOrder) => {
  const billingName =
    [order.billing?.first_name, order.billing?.last_name].filter(Boolean).join(' ') || undefined;
  return {
    id: order.id,
    number: order.number,
    status: toStatus(order.status),
    currency: order.currency,
    total: new Prisma.Decimal(order.total ?? '0'),
    customerNote: order.customer_note ?? null,
    paymentMethod: order.payment_method ?? null,
    billingName,
    billingEmail: order.billing?.email ?? null,
    shippingCity: order.shipping?.city ?? order.billing?.city ?? null,
    createdAt: order.date_created ? new Date(order.date_created) : new Date(),
    updatedAt: order.date_modified ? new Date(order.date_modified) : new Date(),
    items: mapItems(order.line_items ?? []),
  };
};

export const upsertWooOrder = async (order: WooOrder) => {
  const data = mapWooOrder(order);
  return prisma.$transaction(async (tx) => {
    const updated = await tx.order.upsert({
      where: { id: data.id },
      create: {
        ...data,
        items: {
          create: data.items,
        },
      },
      update: {
        number: data.number,
        status: data.status,
        currency: data.currency,
        total: data.total,
        customerNote: data.customerNote,
        paymentMethod: data.paymentMethod,
        billingName: data.billingName,
        billingEmail: data.billingEmail,
        shippingCity: data.shippingCity,
        createdAt: data.createdAt,
        updatedAt: data.updatedAt,
        items: {
          deleteMany: { orderId: data.id },
          create: data.items,
        },
      },
    });
    return updated;
  });
};

export const deleteOrder = (id: number) => prisma.order.delete({ where: { id } });

export type OrderListParams = {
  page: number;
  pageSize: number;
  status?: OrderStatus[];
  search?: string;
  dateFrom?: Date;
  dateTo?: Date;
  sort?: 'created' | 'updated';
  modifiedAfter?: Date;
};

export const listOrders = async (params: OrderListParams) => {
  const where: Prisma.OrderWhereInput = {};
  if (params.status && params.status.length) {
    where.status = { in: params.status };
  }
  if (params.search) {
    where.OR = [
      { number: { contains: params.search, mode: 'insensitive' } },
      { billingName: { contains: params.search, mode: 'insensitive' } },
      { billingEmail: { contains: params.search, mode: 'insensitive' } },
    ];
  }
  if (params.dateFrom || params.dateTo) {
    where.createdAt = {};
    if (params.dateFrom) where.createdAt.gte = params.dateFrom;
    if (params.dateTo) where.createdAt.lte = params.dateTo;
  }
  if (params.modifiedAfter) {
    where.updatedAt = { gt: params.modifiedAfter };
  }

  const orderBy = params.sort === 'created' ? { createdAt: 'desc' } : { updatedAt: 'desc' };

  const [items, total, metrics] = await prisma.$transaction([
    prisma.order.findMany({
      where,
      orderBy,
      skip: (params.page - 1) * params.pageSize,
      take: params.pageSize,
      include: { items: true },
    }),
    prisma.order.count({ where }),
    getOrderMetrics(where),
  ]);

  return { items, total, metrics };
};

export const getOrder = (id: number) =>
  prisma.order.findUnique({ where: { id }, include: { items: true } });

const getOrderMetrics = async (where: Prisma.OrderWhereInput) => {
  const statusAgg = await prisma.order.groupBy({
    by: ['status'],
    _count: { _all: true },
    _sum: { total: true },
    where,
  });

  const todayStart = new Date();
  todayStart.setHours(0, 0, 0, 0);
  const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);

  const [today, last7] = await Promise.all([
    prisma.order.aggregate({
      _sum: { total: true },
      _avg: { total: true },
      where: { ...where, createdAt: { gte: todayStart } },
    }),
    prisma.order.aggregate({
      _sum: { total: true },
      _avg: { total: true },
      where: { ...where, createdAt: { gte: sevenDaysAgo } },
    }),
  ]);

  return {
    byStatus: statusAgg.map((s) => ({
      status: s.status,
      count: s._count._all,
      total: s._sum.total?.toNumber() ?? 0,
    })),
    revenueToday: today._sum.total?.toNumber() ?? 0,
    revenue7d: last7._sum.total?.toNumber() ?? 0,
    avgOrderValue: last7._avg.total?.toNumber() ?? 0,
  };
};
