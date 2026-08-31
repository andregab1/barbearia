function normalizePhone(value) {
  return String(value || '').replace(/\D/g, '');
}

function normalizeEmail(value) {
  return String(value || '').trim().toLowerCase();
}

function slugify(value) {
  return String(value || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 70);
}

function validateOwnerRegistration(body = {}) {
  const data = {
    ownerName: String(body.owner_name || '').trim(),
    shopName: String(body.shop_name || '').trim(),
    email: normalizeEmail(body.email),
    phone: normalizePhone(body.phone),
    password: String(body.password || ''),
    slug: slugify(body.slug || body.shop_name),
  };
  const fields = {};
  if (data.ownerName.length < 2 || data.ownerName.length > 100) fields.owner_name = 'Use de 2 a 100 caracteres.';
  if (data.shopName.length < 2 || data.shopName.length > 150) fields.shop_name = 'Use de 2 a 150 caracteres.';
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(data.email)) fields.email = 'Informe um e-mail válido.';
  if (data.phone.length < 10 || data.phone.length > 15) fields.phone = 'Informe um telefone válido com DDD.';
  if (data.password.length < 8 || !/[A-Za-z]/.test(data.password) || !/\d/.test(data.password)) {
    fields.password = 'Use ao menos 8 caracteres, incluindo letra e número.';
  }
  if (data.slug.length < 3) fields.slug = 'Informe um identificador válido para a barbearia.';
  return { valid: Object.keys(fields).length === 0, data, fields };
}

module.exports = { normalizePhone, normalizeEmail, slugify, validateOwnerRegistration };
