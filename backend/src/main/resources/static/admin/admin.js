// FEYA staff console. Plain ES modules, no build step. Every request is authorized again on the server;
// hiding menu items here is only a convenience.
const API = '/api/v1';
const store = {
  get(k) { try { return sessionStorage.getItem(k); } catch { return null; } },
  set(k, v) { try { sessionStorage.setItem(k, v); } catch { /* ignore */ } },
  del(k) { try { sessionStorage.removeItem(k); } catch { /* ignore */ } },
};
const state = { user: null, page: 'dashboard', params: {} };

// ---------------------------------------------------------------- DOM helpers (text only, never innerHTML)
function h(tag, props = {}, ...kids) {
  const el = document.createElement(tag);
  for (const [k, v] of Object.entries(props || {})) {
    if (v === undefined || v === null || v === false) continue;
    if (k === 'class') el.className = v;
    else if (k.startsWith('on')) el.addEventListener(k.slice(2).toLowerCase(), v);
    else if (k === 'value') el.value = v;
    else if (k === 'checked') el.checked = !!v;
    else el.setAttribute(k, v === true ? '' : v);
  }
  for (const kid of kids.flat()) {
    if (kid === null || kid === undefined || kid === false) continue;
    el.append(kid instanceof Node ? kid : document.createTextNode(String(kid)));
  }
  return el;
}
const money = (n) => (n === null || n === undefined ? '' : Number(n).toLocaleString('ru-RU') + ' ₸');
const dt = (s) => (s ? new Date(s).toLocaleString('ru-RU', { timeZone: 'Asia/Almaty', dateStyle: 'short', timeStyle: 'short' }) : '');
const short = (id) => (id ? String(id).slice(0, 8) : '');

function toast(msg, err = false) {
  const t = h('div', { class: 'toast' + (err ? ' err' : '') }, msg);
  document.body.append(t);
  setTimeout(() => t.remove(), 4200);
}

// ---------------------------------------------------------------- API
let refreshing = null;
async function refreshTokens() {
  const refresh = store.get('refresh');
  if (!refresh) return false;
  refreshing ??= fetch(API + '/auth/refresh', {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ refreshToken: refresh }),
  }).then(async (r) => {
    if (!r.ok) return false;
    const d = await r.json();
    store.set('access', d.accessToken); store.set('refresh', d.refreshToken);
    return true;
  }).catch(() => false).finally(() => { refreshing = null; });
  return refreshing;
}
async function api(method, path, body, retried = false) {
  const headers = { 'Accept-Language': 'ru' };
  const token = store.get('access');
  if (token) headers.Authorization = 'Bearer ' + token;
  let payload;
  if (body instanceof FormData) payload = body;
  else if (body !== undefined) { headers['Content-Type'] = 'application/json'; payload = JSON.stringify(body); }
  let res;
  try { res = await fetch(API + path, { method, headers, body: payload }); }
  catch { throw new Error('Нет соединения с сервером'); }
  if (res.status === 401 && !retried && await refreshTokens()) return api(method, path, body, true);
  if (res.status === 401) { logout(); throw new Error('Сессия истекла'); }
  const text = await res.text();
  const data = text ? JSON.parse(text) : null;
  if (!res.ok) {
    const fields = data?.fieldErrors ? ' (' + Object.entries(data.fieldErrors).map(([k, v]) => k + ': ' + v).join('; ') + ')' : '';
    throw new Error((data?.message || 'Ошибка ' + res.status) + fields);
  }
  return data;
}
const qs = (o) => { const p = new URLSearchParams(); for (const [k, v] of Object.entries(o)) if (v !== '' && v !== null && v !== undefined) p.set(k, v); const s = p.toString(); return s ? '?' + s : ''; };

// ---------------------------------------------------------------- generic UI parts
function statusChip(s) {
  const cls = { DELIVERED: 'ok', PAID: 'pri', CONFIRMED: 'pri', PREPARING: 'pri', READY_FOR_PICKUP: 'pri', COURIER_ASSIGNED: 'pri', PICKED_UP: 'pri', ON_THE_WAY: 'pri',
    CANCELLED: 'err', PAYMENT_FAILED: 'err', REFUNDED: 'warn', PENDING_PAYMENT: 'warn', CREATED: 'warn' }[s] || '';
  return h('span', { class: 'chip ' + cls }, s);
}
function table(cols, rows, { onRow, sort, onSort } = {}) {
  if (!rows.length) return h('div', { class: 'empty card' }, 'Нет данных');
  return h('div', { class: 'tablewrap' }, h('table', {},
    h('thead', {}, h('tr', {}, cols.map((c) => h('th', {
      class: c.sort ? 'sortable' : '', onClick: c.sort && onSort ? () => onSort(c.sort) : null,
    }, c.label + (sort && sort.field === c.sort ? (sort.dir === 'asc' ? ' ▲' : ' ▼') : ''))))),
    h('tbody', {}, rows.map((r) => h('tr', { class: onRow ? 'click' : '', onClick: onRow ? () => onRow(r) : null },
      cols.map((c) => h('td', {}, c.render ? c.render(r) : (r[c.key] ?? ''))))))));
}
function pager(p, go) {
  if (!p || p.totalPages <= 1) return null;
  return h('div', { class: 'pager' },
    h('button', { class: 'btn', disabled: p.page <= 0, onClick: () => go(p.page - 1) }, '←'),
    h('span', {}, `Страница ${p.page + 1} из ${p.totalPages} · всего ${p.totalElements}`),
    h('button', { class: 'btn', disabled: !p.hasNext, onClick: () => go(p.page + 1) }, '→'));
}
function drawer(title, build) {
  const close = () => bg.remove();
  const body = h('div');
  const bg = h('div', { class: 'drawer-bg', onClick: (e) => { if (e.target === bg) close(); } },
    h('div', { class: 'drawer' },
      h('div', { class: 'row', style: 'justify-content:space-between;margin-bottom:12px' }, h('h1', { style: 'margin:0' }, title), h('button', { class: 'btn', onClick: close }, 'Закрыть')),
      body));
  document.body.append(bg);
  build(body, close);
  return close;
}
function field(label, input) { return h('label', { class: 'f' }, label, input); }
function input(v, o = {}) { return h('input', { value: v ?? '', type: o.type || 'text', placeholder: o.ph, min: o.min, max: o.max, step: o.step, required: o.required, maxlength: o.max_len }); }
function select(options, v) { return h('select', {}, options.map(([val, lab]) => { const o = h('option', { value: val }, lab); if (String(val) === String(v)) o.selected = true; return o; })); }
function checkbox(label, v) { const i = h('input', { type: 'checkbox', checked: v }); return { el: h('label', { class: 'chk' }, i, label), get value() { return i.checked; } }; }
async function guarded(btn, fn) {
  btn.disabled = true;
  try { await fn(); } catch (e) { toast(e.message, true); } finally { btn.disabled = false; }
}
function loadInto(box, fn) {
  box.replaceChildren(h('div', { class: 'loading' }, 'Загрузка…'));
  fn().then((el) => box.replaceChildren(el)).catch((e) => box.replaceChildren(h('div', { class: 'card error' }, e.message, ' ', h('button', { class: 'btn', onClick: () => loadInto(box, fn) }, 'Повторить'))));
}
const i18nFields = (label, obj = {}, area = false) => {
  const mk = (l) => (area ? h('textarea', { rows: 3 }, obj?.[l] ?? '') : input(obj?.[l]));
  const els = { ru: mk('ru'), kk: mk('kk'), en: mk('en') };
  return { els, nodes: ['ru', 'kk', 'en'].map((l) => field(`${label} (${l})`, els[l])), value: () => Object.fromEntries(Object.entries(els).filter(([, e]) => e.value.trim()).map(([k, e]) => [k, e.value.trim()])) };
};

// ---------------------------------------------------------------- pages
const pages = {};
function page(id, title, roles, render) { pages[id] = { title, roles, render }; }

page('dashboard', 'Сводка', ['ADMIN', 'SUPPORT'], async () => {
  const d = await api('GET', '/admin/dashboard');
  const m = (l, v) => h('div', { class: 'card metric' }, h('div', { class: 'l' }, l), h('div', { class: 'v' }, v));
  return h('div', {},
    h('div', { class: 'grid' }, m('Заказов сегодня', d.ordersToday), m('Выручка сегодня', money(d.revenueToday)), m('Заказов за 7 дней', d.orders7d),
      m('Выручка за 7 дней', money(d.revenue7d)), m('Новые клиенты (7 дн.)', d.newCustomers7d), m('Заказов в работе', d.openOrders), m('Позиции с остатком ≤ 2', d.lowStockRows)),
    h('h2', {}, 'Заказы по статусам'),
    h('div', {}, Object.entries(d.ordersByStatus).map(([s, n]) => h('span', { style: 'margin-right:10px;display:inline-block;margin-bottom:8px' }, statusChip(s), ' ', n))),
    h('h2', {}, 'Топ товаров (доставленные заказы)'),
    table([{ label: 'Товар', key: 'name' }, { label: 'Штук', key: 'quantity' }, { label: 'Выручка', render: (r) => money(r.revenue) }], d.topProducts));
});

page('orders', 'Заказы', ['ADMIN', 'SUPPORT'], (root) => {
  const f = { status: '', q: '', sort: 'createdAt', dir: 'desc', page: 0 };
  const results = h('div');
  const statuses = ['', 'PENDING_PAYMENT', 'PAID', 'CONFIRMED', 'PREPARING', 'READY_FOR_PICKUP', 'COURIER_ASSIGNED', 'PICKED_UP', 'ON_THE_WAY', 'DELIVERED', 'CANCELLED', 'PAYMENT_FAILED', 'REFUNDED'];
  const st = select(statuses.map((s) => [s, s || 'Все статусы']), f.status);
  const q = input('', { ph: 'Номер, имя или телефон' });
  const load = () => loadInto(results, async () => {
    const p = await api('GET', '/admin/orders' + qs({ status: f.status, q: f.q, sort: f.sort, dir: f.dir, page: f.page, size: 20 }));
    return h('div', {}, table([
      { label: 'Номер', key: 'number', sort: 'number' }, { label: 'Статус', render: (r) => statusChip(r.status), sort: 'status' },
      { label: 'Оплата', key: 'paymentStatus' }, { label: 'Сумма', render: (r) => money(r.total), sort: 'total' }, { label: 'Получатель', key: 'recipientName' },
      { label: 'Дата доставки', key: 'deliveryDate', sort: 'deliveryDate' }, { label: 'Создан', render: (r) => dt(r.createdAt), sort: 'createdAt' },
    ], p.content, { onRow: (r) => orderDrawer(r.id, load), sort: { field: f.sort, dir: f.dir }, onSort: (s) => { f.dir = f.sort === s && f.dir === 'desc' ? 'asc' : 'desc'; f.sort = s; load(); } }), pager(p, (n) => { f.page = n; load(); }));
  });
  st.addEventListener('change', () => { f.status = st.value; f.page = 0; load(); });
  q.addEventListener('keydown', (e) => { if (e.key === 'Enter') { f.q = q.value; f.page = 0; load(); } });
  root.append(h('div', { class: 'toolbar' }, st, q, h('button', { class: 'btn', onClick: () => { f.q = q.value; f.page = 0; load(); } }, 'Найти')), results);
  load();
});

function orderDrawer(id, reload) {
  drawer('Заказ', (body, close) => loadInto(body, async () => {
    const d = await api('GET', '/admin/orders/' + id);
    const o = d.order;
    const isAdmin = state.user.roles.includes('ADMIN');
    const wrap = h('div', {});
    // After any action the drawer is reopened so every figure and the allowed transitions are fresh.
    const act = (label, fn, cls = '') => {
      const b = h('button', { class: 'btn ' + cls }, label);
      b.addEventListener('click', () => guarded(b, async () => { await fn(); toast('Готово'); reload?.(); close(); orderDrawer(id, reload); }));
      return b;
    };
    wrap.append(
      h('div', { class: 'row' }, h('h2', { style: 'margin:0' }, o.number), statusChip(o.status), h('span', { class: 'chip' }, o.paymentStatus), h('strong', {}, money(o.total))),
      h('p', { class: 'muted' }, `Создан ${dt(o.createdAt)} · флорист ${short(d.floristId)} · курьер ${short(d.courierId) || '—'}`),
      h('h2', {}, 'Доставка'),
      h('div', { class: 'card' }, h('div', {}, `${o.address.city}, ${o.address.street} ${o.address.building}${o.address.apartment ? ', кв. ' + o.address.apartment : ''}`),
        h('div', {}, o.asap ? 'Как можно скорее' : `${o.deliveryDate} ${o.slotStart ?? ''}–${o.slotEnd ?? ''}`), h('div', {}, `Получатель: ${o.recipientName} ${o.recipientPhone}`),
        o.giftMessage ? h('div', { class: 'muted' }, 'Открытка: ' + o.giftMessage) : null),
      h('h2', {}, 'Состав'), table([{ label: 'Товар', render: (r) => r.name + ' · ' + r.variantLabel }, { label: 'Кол-во', key: 'quantity' }, { label: 'Сумма', render: (r) => money(r.lineTotal) }], o.items),
      h('h2', {}, 'Платежи'), table([{ label: 'Провайдер', render: (r) => r.provider + (r.sandbox ? ' (тест)' : '') }, { label: 'Метод', key: 'method' }, { label: 'Статус', key: 'status' }, { label: 'Сумма', render: (r) => money(r.amount) }, { label: 'Возвращено', render: (r) => money(r.refunded) }], d.payments),
      d.refunds.length ? [h('h2', {}, 'Возвраты'), table([{ label: 'Сумма', render: (r) => money(r.amount) }, { label: 'Статус', key: 'status' }, { label: 'Причина', key: 'reason' }, { label: 'Когда', render: (r) => dt(r.createdAt) }], d.refunds)] : null,
      h('h2', {}, 'История'), table([{ label: 'Статус', render: (r) => statusChip(r.status) }, { label: 'Время', render: (r) => dt(r.at) }], o.timeline),
      h('h2', {}, 'Действия'),
      h('div', { class: 'row' }, d.allowedNext.map((s) => act('→ ' + s, async () => {
        const note = s === 'CANCELLED' ? prompt('Причина (необязательно)') : null;
        await api('POST', `/admin/orders/${id}/status`, { status: s, note });
      }, s === 'CANCELLED' ? 'danger' : ''))),
      d.allowedNext.length ? null : h('p', { class: 'muted' }, 'Для этого статуса нет доступных переходов.'));
    if (o.status === 'READY_FOR_PICKUP') {
      const cs = select([], '');
      api('GET', '/admin/couriers').then((list) => { cs.replaceChildren(...list.filter((c) => c.active).map((c) => h('option', { value: c.userId }, `${c.name || c.phone} ${c.onShift ? '(на смене)' : ''}`))); });
      wrap.append(h('div', { class: 'row', style: 'margin-top:12px' }, field('Курьер', cs), act('Назначить курьера', () => api('POST', `/admin/orders/${id}/assign-courier`, { courierId: cs.value }))));
    }
    if (isAdmin && o.paymentStatus === 'PAID' && o.status === 'DELIVERED') {
      const amount = input('', { type: 'number', ph: 'Вся сумма' }); const reason = input('', { ph: 'Причина' });
      wrap.append(h('h2', {}, 'Возврат'), h('div', { class: 'row' }, field('Сумма (пусто = полностью)', amount), field('Причина', reason),
        act('Оформить возврат', () => api('POST', `/admin/orders/${id}/refund`, { amount: amount.value ? Number(amount.value) : null, reason: reason.value || null }), 'danger')));
    }
    return wrap;
  }));
}

page('floristOrders', 'Очередь флориста', ['FLORIST', 'ADMIN'], (root) => {
  const results = h('div');
  const florist = state.user.roles.includes('ADMIN') ? input('', { ph: 'ID флориста (необязательно)' }) : null;
  const load = () => loadInto(results, async () => {
    const p = await api('GET', '/florist/orders' + qs({ floristId: florist?.value, size: 50 }));
    return table([
      { label: 'Номер', key: 'number' }, { label: 'Статус', render: (r) => statusChip(r.status) },
      { label: 'Состав', render: (r) => r.items.map((i) => `${i.name} (${i.variantLabel}) ×${i.quantity}`).join(', ') },
      { label: 'Когда', render: (r) => (r.asap ? 'Срочно' : `${r.deliveryDate} ${r.slotStart ?? ''}–${r.slotEnd ?? ''}`) },
      { label: 'Открытка / комментарий', render: (r) => [r.giftWrap ? 'Подарочная упаковка' : null, r.giftMessage, r.instructions].filter(Boolean).join(' · ') },
      { label: '', render: (r) => h('div', { class: 'row' }, r.allowedNext.filter((s) => ['CONFIRMED', 'PREPARING', 'READY_FOR_PICKUP', 'CANCELLED'].includes(s)).map((s) => {
        const path = { CONFIRMED: 'accept', PREPARING: 'preparing', READY_FOR_PICKUP: 'ready', CANCELLED: 'reject' }[s];
        const b = h('button', { class: 'btn ' + (s === 'CANCELLED' ? 'danger' : 'primary') }, { CONFIRMED: 'Принять', PREPARING: 'Собираю', READY_FOR_PICKUP: 'Готов', CANCELLED: 'Отклонить' }[s]);
        b.addEventListener('click', () => guarded(b, async () => { await api('POST', `/florist/orders/${r.id}/${path}`, s === 'CANCELLED' ? { reason: prompt('Причина отказа') || 'rejected by florist' } : undefined); toast('Готово'); load(); }));
        return b; })) },
    ], p.content);
  });
  root.append(h('div', { class: 'toolbar' }, florist, h('button', { class: 'btn', onClick: load }, 'Обновить')), results);
  load();
});

page('products', 'Товары', ['ADMIN', 'FLORIST'], (root) => {
  const f = { q: '', page: 0 };
  const results = h('div');
  const q = input('', { ph: 'Поиск' });
  const load = () => loadInto(results, async () => {
    const p = await api('GET', '/florist/products' + qs({ q: f.q, page: f.page, size: 20 }));
    return h('div', {}, table([
      { label: 'Название', render: (r) => r.name.ru }, { label: 'Slug', key: 'slug' }, { label: 'Категория', key: 'categorySlug' }, { label: 'От', render: (r) => money(r.priceFrom) },
      { label: 'Размеры', render: (r) => r.variants.filter((v) => v.active).map((v) => v.code).join(', ') },
      { label: 'Статус', render: (r) => h('span', { class: 'chip ' + (r.active ? 'ok' : 'err') }, r.active ? 'активен' : 'скрыт') },
    ], p.content, { onRow: (r) => productDrawer(r, load) }), pager(p, (n) => { f.page = n; load(); }));
  });
  q.addEventListener('keydown', (e) => { if (e.key === 'Enter') { f.q = q.value; f.page = 0; load(); } });
  root.append(h('div', { class: 'toolbar' }, q, h('button', { class: 'btn primary', onClick: () => productDrawer(null, load) }, '+ Новый товар')), results);
  load();
});

async function productDrawer(existing, reload) {
  const cats = await api('GET', '/categories?lang=ru').catch(() => []);
  const categories = cats.length ? cats.map((c) => [c.slug, c.name]) : [['mixed', 'mixed']];
  drawer(existing ? existing.name.ru : 'Новый товар', (body, close) => {
    const p = existing || { slug: '', categorySlug: categories[0][0], name: {}, description: {}, composition: {}, prepMinutes: 90, active: true, featured: false, seasonal: false, gift: false, images: [], variants: [] };
    const slug = input(p.slug); const cat = select(categories, p.categorySlug);
    const name = i18nFields('Название', p.name); const desc = i18nFields('Описание', p.description, true); const comp = i18nFields('Состав', p.composition);
    const prep = input(p.prepMinutes, { type: 'number', min: 10 });
    const active = checkbox('Активен', p.active), featured = checkbox('Хит', p.featured), seasonal = checkbox('Сезонный', p.seasonal), gift = checkbox('Подарок', p.gift);
    const codes = ['SMALL', 'STANDARD', 'LARGE', 'PREMIUM'];
    const vrows = codes.map((code) => {
      const v = p.variants.find((x) => x.code === code);
      return { code, label: i18nFields('Название', v?.label || { ru: { SMALL: 'Малый', STANDARD: 'Стандартный', LARGE: 'Большой', PREMIUM: 'Премиум' }[code], kk: '', en: { SMALL: 'Small', STANDARD: 'Standard', LARGE: 'Large', PREMIUM: 'Premium' }[code] }),
        price: input(v?.price ?? '', { type: 'number', min: 1 }), stems: input(v?.stemsCount ?? '', { type: 'number', min: 1 }), on: checkbox('Включён', v ? v.active : false), exists: !!v };
    });
    body.append(h('div', { class: 'form' }, field('Slug', slug), field('Категория', cat), field('Время сборки, мин', prep), h('div', {}, active.el, featured.el, seasonal.el, gift.el),
      name.nodes, desc.nodes.map((n) => h('div', { class: 'wide' }, n)), comp.nodes));
    body.append(h('h2', {}, 'Размеры и цены (KZT)'));
    for (const r of vrows) body.append(h('div', { class: 'card', style: 'margin-bottom:10px' }, h('strong', {}, r.code), h('div', { class: 'form' }, r.label.nodes[0], r.label.nodes[1], r.label.nodes[2], field('Цена', r.price), field('Стеблей', r.stems), r.on.el)));
    const save = h('button', { class: 'btn primary' }, existing ? 'Сохранить' : 'Создать');
    save.addEventListener('click', () => guarded(save, async () => {
      const variants = vrows.filter((r) => r.on.value || r.exists).filter((r) => r.price.value).map((r) => ({ code: r.code, label: r.label.value(), price: Number(r.price.value), stemsCount: r.stems.value ? Number(r.stems.value) : null, active: r.on.value }));
      const payload = { slug: slug.value.trim(), categorySlug: cat.value, name: name.value(), description: desc.value(), composition: comp.value(), featured: featured.value, seasonal: seasonal.value, gift: gift.value, prepMinutes: Number(prep.value), active: active.value, variants };
      await api(existing ? 'PUT' : 'POST', '/florist/products' + (existing ? '/' + existing.id : ''), payload);
      toast('Сохранено'); close(); reload();
    }));
    body.append(h('div', { class: 'row', style: 'margin-top:14px' }, save));
    if (existing) {
      body.append(h('h2', {}, 'Изображения'));
      const imgs = h('div', { class: 'row' });
      const draw = (list) => imgs.replaceChildren(...list.map((i) => h('div', { class: 'card' }, h('img', { src: i.url, alt: '', style: 'width:110px;height:138px;object-fit:cover;border-radius:8px;display:block' }),
        h('button', { class: 'btn danger', style: 'margin-top:6px', onClick: (e) => guarded(e.target, async () => { const r = await api('DELETE', `/florist/products/${existing.id}/images/${i.id}`); draw(r.images); }) }, 'Убрать'))));
      draw(existing.images);
      const url = input('', { ph: 'https://… или /media/…' });
      const file = h('input', { type: 'file', accept: 'image/jpeg,image/png,image/webp' });
      body.append(imgs, h('div', { class: 'row', style: 'margin-top:10px' }, field('Добавить по ссылке', url),
        h('button', { class: 'btn', onClick: (e) => guarded(e.target, async () => { const r = await api('POST', `/florist/products/${existing.id}/images`, { url: url.value }); draw(r.images); url.value = ''; }) }, 'Добавить'),
        field('Или загрузить файл', file),
        h('button', { class: 'btn', onClick: (e) => guarded(e.target, async () => { if (!file.files[0]) throw new Error('Выберите файл'); const fd = new FormData(); fd.append('file', file.files[0]); const r = await api('POST', `/florist/products/${existing.id}/images/upload`, fd); draw(r.images); }) }, 'Загрузить')));
    }
  });
}

page('categories', 'Категории', ['ADMIN'], (root) => crud(root, {
  list: () => api('GET', '/admin/categories'), path: '/admin/categories',
  cols: [{ label: 'Название', render: (r) => r.name.ru }, { label: 'Slug', key: 'slug' }, { label: 'Порядок', key: 'sortOrder' }, { label: 'Активна', render: (r) => (r.active ? 'да' : 'нет') }],
  form: (r) => { const slug = input(r?.slug); const name = i18nFields('Название', r?.name); const order = input(r?.sortOrder ?? 0, { type: 'number' }); const act = checkbox('Активна', r?.active ?? true);
    return { nodes: [field('Slug', slug), ...name.nodes, field('Порядок', order), act.el], value: () => ({ slug: slug.value.trim(), name: name.value(), sortOrder: Number(order.value), active: act.value }) }; },
}));

page('inventory', 'Остатки', ['ADMIN', 'FLORIST'], (root) => {
  const isAdmin = state.user.roles.includes('ADMIN');
  const results = h('div');
  let floristSel = null;
  const load = () => loadInto(results, async () => {
    const rows = await api('GET', '/florist/inventory' + qs({ floristId: floristSel?.value }));
    return table([{ label: 'Товар', key: 'productName' }, { label: 'Размер', render: (r) => `${r.variantLabel} (${r.variantCode})` },
      { label: 'Остаток', render: (r) => { const i = input(r.quantity, { type: 'number', min: 0 }); i.style.width = '90px';
        const b = h('button', { class: 'btn', style: 'margin-left:8px' }, 'Сохранить'); b.addEventListener('click', () => guarded(b, async () => { await api('PUT', `/florist/inventory/${r.variantId}` + qs({ floristId: floristSel?.value }), { quantity: Number(i.value) }); toast('Сохранено'); }));
        return h('div', {}, i, b); } }], rows);
  });
  const start = async () => {
    if (isAdmin) {
      const fl = await api('GET', '/admin/florists');
      floristSel = select(fl.map((f) => [f.id, f.name]), fl[0]?.id);
      floristSel.addEventListener('change', load);
      root.prepend(h('div', { class: 'toolbar' }, field('Флорист', floristSel)));
    }
    load();
  };
  root.append(results); start().catch((e) => toast(e.message, true));
});

page('customers', 'Клиенты и сотрудники', ['ADMIN', 'SUPPORT'], (root) => {
  const f = { q: '', role: '', page: 0 }; const results = h('div');
  const q = input('', { ph: 'Телефон или имя' });
  const role = select([['', 'Все роли'], ['CUSTOMER', 'CUSTOMER'], ['ADMIN', 'ADMIN'], ['FLORIST', 'FLORIST'], ['COURIER', 'COURIER'], ['SUPPORT', 'SUPPORT']], '');
  const isAdmin = state.user.roles.includes('ADMIN');
  const load = () => loadInto(results, async () => {
    const p = await api('GET', '/admin/customers' + qs({ q: f.q, role: f.role, page: f.page, size: 20 }));
    return h('div', {}, table([{ label: 'Телефон', key: 'phone' }, { label: 'Имя', key: 'name' }, { label: 'Роли', render: (r) => r.roles.join(', ') }, { label: 'Статус', key: 'status' }, { label: 'Регистрация', render: (r) => dt(r.createdAt) }],
      p.content, { onRow: isAdmin ? (r) => userDrawer(r, load) : null }), pager(p, (n) => { f.page = n; load(); }));
  });
  q.addEventListener('keydown', (e) => { if (e.key === 'Enter') { f.q = q.value; f.page = 0; load(); } });
  role.addEventListener('change', () => { f.role = role.value; f.page = 0; load(); });
  root.append(h('div', { class: 'toolbar' }, q, role), results); load();
});
async function userDrawer(u, reload) {
  const florists = await api('GET', '/admin/florists');
  drawer(u.phone, (body, close) => {
    const roles = ['ADMIN', 'FLORIST', 'COURIER', 'SUPPORT'].map((r) => checkbox(r, u.roles.includes(r)));
    const fl = select([['', '—'], ...florists.map((f) => [f.id, f.name])], u.floristId || '');
    const status = select(['ACTIVE', 'BLOCKED', 'DELETION_REQUESTED'].map((s) => [s, s]), u.status);
    body.append(h('p', { class: 'muted' }, `${u.name || 'без имени'} · создан ${dt(u.createdAt)} · вход ${dt(u.lastLoginAt)}`), h('h2', {}, 'Роли'), h('div', { class: 'row' }, roles.map((r) => r.el)), field('Флорист (для роли FLORIST)', fl),
      h('div', { class: 'row', style: 'margin-top:12px' }, h('button', { class: 'btn primary', onClick: (e) => guarded(e.target, async () => { await api('PUT', `/admin/customers/${u.id}/roles`, { roles: roles.filter((r) => r.value).map((r, i) => ['ADMIN', 'FLORIST', 'COURIER', 'SUPPORT'][roles.indexOf(r)]), floristId: fl.value || null }); toast('Роли сохранены'); close(); reload(); }) }, 'Сохранить роли')),
      h('h2', {}, 'Статус аккаунта'), h('div', { class: 'row' }, status, h('button', { class: 'btn', onClick: (e) => guarded(e.target, async () => { await api('PATCH', `/admin/customers/${u.id}/status`, { status: status.value }); toast('Статус обновлён'); close(); reload(); }) }, 'Применить')));
  });
}

page('florists', 'Флористы', ['ADMIN', 'SUPPORT'], async (root) => {
  const zones = state.user.roles.includes('ADMIN') ? await api('GET', '/admin/zones') : [];
  crud(root, {
    list: () => api('GET', '/admin/florists'), path: '/admin/florists', readOnly: !state.user.roles.includes('ADMIN'),
    cols: [{ label: 'Название', key: 'name' }, { label: 'Город', key: 'city' }, { label: 'Адрес', key: 'address' }, { label: 'Телефон', key: 'phone' }, { label: 'Приоритет', key: 'priority' }, { label: 'Активен', render: (r) => (r.active ? 'да' : 'нет') }],
    form: (r) => { const name = input(r?.name), city = input(r?.city || 'Алматы'), addr = input(r?.address), phone = input(r?.phone), prio = input(r?.priority ?? 100, { type: 'number' }); const act = checkbox('Активен', r?.active ?? true);
      const zs = zones.map((z) => ({ z, c: checkbox(z.name.ru, (r?.zoneIds || []).includes(z.id)) }));
      return { nodes: [field('Название', name), field('Город', city), field('Адрес', addr), field('Телефон', phone), field('Приоритет (меньше = раньше)', prio), act.el, h('div', { class: 'wide' }, h('strong', {}, 'Обслуживает зоны'), zs.map((x) => x.c.el))],
        value: () => ({ name: name.value, city: city.value, address: addr.value || null, phone: phone.value || null, priority: Number(prio.value), active: act.value, zoneIds: zs.filter((x) => x.c.value).map((x) => x.z.id) }) }; },
  });
});

page('couriers', 'Курьеры', ['ADMIN', 'SUPPORT'], (root) => crud(root, {
  list: () => api('GET', '/admin/couriers'), path: '/admin/couriers', idKey: 'userId', createOnly: true, readOnly: !state.user.roles.includes('ADMIN'),
  cols: [{ label: 'Телефон', key: 'phone' }, { label: 'Имя', key: 'name' }, { label: 'Транспорт', key: 'vehicle' }, { label: 'Активен', render: (r) => (r.active ? 'да' : 'нет') }, { label: 'На смене', render: (r) => (r.onShift ? 'да' : 'нет') }, { label: 'Геопозиция', render: (r) => (r.locationSharing ? 'передаёт' : 'выкл.') }],
  form: (r) => { const phone = input(r?.phone); const name = input(r?.name); const veh = input(r?.vehicle); const act = checkbox('Активен', r?.active ?? true);
    return { nodes: [field('Телефон', phone), field('Имя', name), field('Транспорт', veh), act.el], value: () => ({ phone: phone.value, name: name.value || null, vehicle: veh.value || null, active: act.value }) }; },
}));

page('zones', 'Зоны и слоты', ['ADMIN'], (root) => crud(root, {
  list: () => api('GET', '/admin/zones'), path: '/admin/zones',
  cols: [{ label: 'Код', key: 'code' }, { label: 'Название', render: (r) => r.name.ru }, { label: 'Радиус, км', key: 'radiusKm' }, { label: 'Доставка', render: (r) => money(r.baseFee) }, { label: 'Бесплатно от', render: (r) => money(r.freeDeliveryThreshold) },
    { label: 'ASAP', render: (r) => (r.asapEnabled ? `да (${r.asapEtaMinutes} мин, ${money(r.asapFee)})` : 'нет') }, { label: 'Активна', render: (r) => (r.active ? 'да' : 'нет') }],
  extra: (r, reload) => slotsDrawer(r),
  form: (r) => { const code = input(r?.code), city = input(r?.cityCode || 'almaty'), al = input(r?.cityAliases || 'алматы,almaty'), name = i18nFields('Название', r?.name);
    const lat = input(r?.centerLat ?? 43.2389, { type: 'number', step: 'any' }), lng = input(r?.centerLng ?? 76.9455, { type: 'number', step: 'any' }), rad = input(r?.radiusKm ?? 10, { type: 'number', step: 'any' });
    const fee = input(r?.baseFee ?? 1500, { type: 'number' }), free = input(r?.freeDeliveryThreshold ?? '', { type: 'number' }); const asap = checkbox('Срочная доставка', r?.asapEnabled), asapFee = input(r?.asapFee ?? 0, { type: 'number' }), eta = input(r?.asapEtaMinutes ?? 90, { type: 'number' });
    const ws = input((r?.workStart || '09:00:00').slice(0, 5), { type: 'time' }), we = input((r?.workEnd || '21:00:00').slice(0, 5), { type: 'time' }); const def = checkbox('Зона по умолчанию для города', r?.defaultZone), act = checkbox('Активна', r?.active ?? true);
    return { nodes: [field('Код', code), field('Код города', city), field('Названия города (через запятую, нижний регистр)', al), ...name.nodes, field('Центр, широта', lat), field('Центр, долгота', lng), field('Радиус, км', rad), field('Стоимость доставки', fee), field('Бесплатно от', free),
      asap.el, field('Наценка за срочность', asapFee), field('ETA срочной, мин', eta), field('Работает с', ws), field('Работает до', we), def.el, act.el],
      value: () => ({ code: code.value.trim(), cityCode: city.value.trim(), cityAliases: al.value, name: name.value(), centerLat: Number(lat.value), centerLng: Number(lng.value), radiusKm: Number(rad.value), baseFee: Number(fee.value), freeDeliveryThreshold: free.value ? Number(free.value) : null,
        asapEnabled: asap.value, asapFee: Number(asapFee.value || 0), asapEtaMinutes: Number(eta.value), workStart: ws.value, workEnd: we.value, defaultZone: def.value, active: act.value }) }; },
}));
function slotsDrawer(zone) {
  drawer('Слоты: ' + zone.name.ru, (body) => {
    const box = h('div');
    const load = () => loadInto(box, async () => {
      const slots = await api('GET', `/admin/zones/${zone.id}/slots`);
      return h('div', {}, table([{ label: 'Время', render: (s) => `${s.startTime.slice(0, 5)}–${s.endTime.slice(0, 5)}` }, { label: 'Вместимость', key: 'capacity' }, { label: 'Дедлайн, мин до начала', key: 'cutoffMinutes' }, { label: 'Наценка', render: (s) => money(s.surcharge) }, { label: 'Дни', key: 'daysOfWeek' }, { label: 'Активен', render: (s) => (s.active ? 'да' : 'нет') }],
        slots, { onRow: (s) => slotForm(zone, s, load) }), h('div', { class: 'row', style: 'margin-top:12px' }, h('button', { class: 'btn primary', onClick: () => slotForm(zone, null, load) }, '+ Слот')));
    });
    body.append(box); load();
  });
}
function slotForm(zone, s, reload) {
  drawer(s ? 'Слот' : 'Новый слот', (body, close) => {
    const a = input(s?.startTime?.slice(0, 5) || '10:00', { type: 'time' }), b = input(s?.endTime?.slice(0, 5) || '12:00', { type: 'time' }), cap = input(s?.capacity ?? 6, { type: 'number', min: 1 }), cut = input(s?.cutoffMinutes ?? 120, { type: 'number', min: 0 }), sur = input(s?.surcharge ?? 0, { type: 'number', min: 0 }), days = input(s?.daysOfWeek || '1,2,3,4,5,6,7'); const act = checkbox('Активен', s?.active ?? true);
    body.append(h('div', { class: 'form' }, field('Начало', a), field('Конец', b), field('Вместимость', cap), field('Дедлайн, мин', cut), field('Наценка', sur), field('Дни недели (1=Пн)', days), act.el),
      h('div', { class: 'row', style: 'margin-top:12px' }, h('button', { class: 'btn primary', onClick: (e) => guarded(e.target, async () => {
        const payload = { startTime: a.value, endTime: b.value, capacity: Number(cap.value), cutoffMinutes: Number(cut.value), surcharge: Number(sur.value || 0), daysOfWeek: days.value, active: act.value };
        await api(s ? 'PUT' : 'POST', s ? `/admin/slots/${s.id}` : `/admin/zones/${zone.id}/slots`, payload); toast('Сохранено'); close(); reload(); }) }, 'Сохранить')));
  });
}

page('promos', 'Акции', ['ADMIN'], (root) => {
  crud(root, {
    list: () => api('GET', '/admin/promos'), path: '/admin/promos',
    cols: [{ label: 'Код', key: 'code' }, { label: 'Тип', key: 'type' }, { label: 'Значение', key: 'value' }, { label: 'Мин. заказ', render: (r) => money(r.minOrder) }, { label: 'Использовано', render: (r) => `${r.usedCount}${r.usageLimit ? '/' + r.usageLimit : ''}` }, { label: 'Действует до', render: (r) => dt(r.validUntil) }, { label: 'Активен', render: (r) => (r.active ? 'да' : 'нет') }],
    form: (r) => { const code = input(r?.code), type = select([['PERCENT', 'Процент'], ['FIXED', 'Фиксированная сумма']], r?.type), val = input(r?.value, { type: 'number', step: 'any' }), min = input(r?.minOrder ?? 0, { type: 'number' }), max = input(r?.maxDiscount ?? '', { type: 'number' }),
      from = input(r?.validFrom ? r.validFrom.slice(0, 16) : '', { type: 'datetime-local' }), until = input(r?.validUntil ? r.validUntil.slice(0, 16) : '', { type: 'datetime-local' }), lim = input(r?.usageLimit ?? '', { type: 'number' }), per = input(r?.perUserLimit ?? '', { type: 'number' }); const act = checkbox('Активен', r?.active ?? true);
      return { nodes: [field('Код', code), field('Тип', type), field('Значение', val), field('Мин. сумма заказа', min), field('Макс. скидка', max), field('Действует с (UTC)', from), field('Действует до (UTC)', until), field('Общий лимит', lim), field('Лимит на клиента', per), act.el],
        value: () => ({ code: code.value.trim(), type: type.value, value: Number(val.value), minOrder: Number(min.value || 0), maxDiscount: max.value ? Number(max.value) : null, validFrom: from.value ? from.value + ':00Z' : null, validUntil: until.value ? until.value + ':00Z' : null, usageLimit: lim.value ? Number(lim.value) : null, perUserLimit: per.value ? Number(per.value) : null, active: act.value }) }; },
  });
  const bannersBox = h('div'); root.append(h('h2', {}, 'Баннеры главной'), bannersBox);
  crud(bannersBox, {
    list: () => api('GET', '/admin/banners'), path: '/admin/banners',
    cols: [{ label: 'Заголовок', render: (r) => r.title.ru }, { label: 'Промокод', key: 'promoCode' }, { label: 'Цель', render: (r) => (r.targetType ? `${r.targetType}: ${r.targetValue}` : '') }, { label: 'Порядок', key: 'sortOrder' }, { label: 'Активен', render: (r) => (r.active ? 'да' : 'нет') }],
    form: (r) => { const t = i18nFields('Заголовок', r?.title), s = i18nFields('Подзаголовок', r?.subtitle), img = input(r?.imageUrl), pc = input(r?.promoCode), tt = select([['', '—'], ['category', 'category']], r?.targetType || ''), tv = input(r?.targetValue), ord = input(r?.sortOrder ?? 0, { type: 'number' }); const act = checkbox('Активен', r?.active ?? true);
      return { nodes: [...t.nodes, ...s.nodes, field('Картинка (/media/… или https://…)', img), field('Промокод', pc), field('Тип цели', tt), field('Значение цели (slug)', tv), field('Порядок', ord), act.el],
        value: () => ({ title: t.value(), subtitle: s.value(), imageUrl: img.value || null, promoCode: pc.value || null, targetType: tt.value || null, targetValue: tv.value || null, sortOrder: Number(ord.value), active: act.value }) }; },
  });
});

page('reviews', 'Отзывы', ['ADMIN', 'SUPPORT'], (root) => {
  const f = { status: '', page: 0 }; const results = h('div');
  const st = select([['', 'Все'], ['PUBLISHED', 'Опубликованные'], ['HIDDEN', 'Скрытые']], '');
  const load = () => loadInto(results, async () => {
    const p = await api('GET', '/admin/reviews' + qs({ status: f.status, page: f.page, size: 20 }));
    return h('div', {}, table([{ label: 'Оценка', key: 'rating' }, { label: 'Текст', key: 'text' }, { label: 'Проверенная покупка', render: (r) => (r.verified ? 'да' : 'нет') }, { label: 'Статус', key: 'status' }, { label: 'Когда', render: (r) => dt(r.createdAt) },
      { label: '', render: (r) => { const b = h('button', { class: 'btn' }, r.status === 'HIDDEN' ? 'Показать' : 'Скрыть'); b.addEventListener('click', () => guarded(b, async () => { await api('POST', `/admin/reviews/${r.id}/${r.status === 'HIDDEN' ? 'unhide' : 'hide'}`); load(); })); return b; } }], p.content), pager(p, (n) => { f.page = n; load(); }));
  });
  st.addEventListener('change', () => { f.status = st.value; f.page = 0; load(); });
  root.append(h('div', { class: 'toolbar' }, st), results); load();
});

page('audit', 'Аудит', ['ADMIN'], (root) => {
  const f = { page: 0 }; const results = h('div');
  const load = () => loadInto(results, async () => {
    const p = await api('GET', '/admin/audit' + qs({ page: f.page, size: 50 }));
    return h('div', {}, table([{ label: 'Когда', render: (r) => dt(r.createdAt) }, { label: 'Роль', key: 'actorRole' }, { label: 'Действие', key: 'action' }, { label: 'Объект', render: (r) => `${r.entityType} ${short(r.entityId)}` }, { label: 'Детали', key: 'details' }], p.content), pager(p, (n) => { f.page = n; load(); }));
  });
  root.append(results); load();
});

// Generic CRUD list + drawer form
function crud(root, { list, path, cols, form, idKey = 'id', createOnly = false, readOnly = false, extra }) {
  const box = h('div');
  const load = () => loadInto(box, async () => table(cols, await list(), { onRow: (r) => openForm(r) }));
  const openForm = (r) => {
    drawer(r ? 'Редактирование' : 'Создание', (body, close) => {
      const f = form(r);
      body.append(h('div', { class: 'form' }, f.nodes));
      if (!readOnly) {
        body.append(h('div', { class: 'row', style: 'margin-top:14px' }, h('button', { class: 'btn primary', onClick: (e) => guarded(e.target, async () => {
          const method = r ? (createOnly ? 'PATCH' : 'PUT') : 'POST';
          await api(method, r ? `${path}/${r[idKey]}` : path, f.value());
          toast('Сохранено'); close(); load();
        }) }, 'Сохранить')));
      }
      if (extra && r) body.append(h('div', { class: 'row', style: 'margin-top:12px' }, h('button', { class: 'btn', onClick: () => extra(r, load) }, 'Слоты доставки')));
    });
  };
  root.append(h('div', { class: 'toolbar' }, readOnly ? null : h('button', { class: 'btn primary', onClick: () => openForm(null) }, '+ Добавить')), box);
  load();
}

// ---------------------------------------------------------------- shell, login, routing
function logout() {
  const refresh = store.get('refresh');
  if (refresh) fetch(API + '/auth/logout', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ refreshToken: refresh }) }).catch(() => {});
  store.del('access'); store.del('refresh'); state.user = null; render();
}
function renderLogin(app) {
  let phase = 'phone'; let phone = '';
  const box = h('div', { class: 'login' });
  const draw = (err = '', dev = '') => {
    const p = input(phone || '+7', { type: 'tel' }); const c = input(dev, { ph: 'Код из SMS', max_len: 8 });
    const go = h('button', { class: 'btn primary', style: 'width:100%' }, phase === 'phone' ? 'Получить код' : 'Войти');
    go.addEventListener('click', () => guarded(go, async () => {
      try {
        if (phase === 'phone') { phone = p.value; const r = await api('POST', '/auth/otp/request', { phone }); phase = 'code'; draw('', r.devCode || ''); }
        else { const r = await api('POST', '/auth/otp/verify', { phone, code: c.value }); if (!r.user.roles.some((x) => ['ADMIN', 'SUPPORT', 'FLORIST'].includes(x))) throw new Error('У аккаунта нет доступа к консоли'); store.set('access', r.accessToken); store.set('refresh', r.refreshToken); state.user = r.user; render(); }
      } catch (e) { draw(e.message); }
    }));
    box.replaceChildren(h('h1', {}, 'FEYA · Консоль'), h('div', { class: 'card', style: 'display:grid;gap:12px' }, phase === 'phone' ? field('Телефон сотрудника', p) : field('Код подтверждения', c), dev ? h('div', { class: 'muted' }, 'Режим разработки: код подставлен.') : null, err ? h('div', { class: 'error' }, err) : null, go));
  };
  draw(); app.replaceChildren(box);
}
function render() {
  const app = document.getElementById('app');
  if (!state.user) { renderLogin(app); return; }
  const roles = state.user.roles;
  const allowed = Object.entries(pages).filter(([, p]) => p.roles.some((r) => roles.includes(r)));
  if (!pages[state.page] || !pages[state.page].roles.some((r) => roles.includes(r))) state.page = allowed[0]?.[0];
  const main = h('main', {});
  const nav = h('nav', { class: 'side' }, h('div', { class: 'logo' }, h('i'), 'FEYA'),
    allowed.map(([id, p]) => h('button', { class: 'nav' + (id === state.page ? ' active' : ''), onClick: () => { state.page = id; location.hash = id; render(); } }, p.title)),
    h('div', { class: 'who' }, h('div', {}, state.user.name || state.user.phone), h('div', {}, roles.filter((r) => r !== 'CUSTOMER').join(', ')), h('button', { class: 'btn', style: 'margin-top:8px', onClick: logout }, 'Выйти')));
  app.replaceChildren(h('div', { class: 'shell' }, nav, main));
  if (state.page) {
    main.append(h('h1', {}, pages[state.page].title));
    const res = pages[state.page].render(main);
    // Async pages return a promise: a Node (dashboard) to display, or nothing when they populate `main` themselves.
    if (res && typeof res.then === 'function') {
      const holder = h('div');
      main.append(holder);
      loadInto(holder, async () => { const out = await res; return out instanceof Node ? out : h('div'); });
    }
  }
}
async function boot() {
  const hash = location.hash.slice(1); if (pages[hash]) state.page = hash;
  if (store.get('access') || store.get('refresh')) {
    try { state.user = await api('GET', '/me'); } catch { state.user = null; }
  }
  render();
}
boot();
