// Database DATETIME values represent the shop's wall clock in Sao Paulo.
function parseLocal(value) {
  const text = String(value).replace(' ', 'T');
  if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2})?$/.test(text)) return new Date(NaN);
  const normalized = text.length === 16 ? `${text}:00` : text;
  const result = new Date(`${normalized}-03:00`);
  return Number.isNaN(+result) || formatLocal(result).replace(' ', 'T') !== normalized ? new Date(NaN) : result;
}
function formatLocal(value) {
  return new Date(+value - 3 * 3600000).toISOString().slice(0, 19).replace('T', ' ');
}
function nextDate(date, days = 1) {
  return new Date(Date.parse(`${date}T12:00:00Z`) + days * 86400000).toISOString().slice(0, 10);
}
async function availableSlots(db, professionalId, date, duration, now = new Date()) {
  if (Number.isNaN(+parseLocal(`${date} 12:00:00`)) || !Number.isInteger(duration) || duration <= 0) return [];
  const next = nextDate(date);
  const [[working], [appointments], [blocks]] = await Promise.all([
    db.query('SELECT hora_inicio, hora_fim FROM horarios_funcionamento WHERE colaborador_id = ? AND dia_semana = ? AND ativo = 1', [professionalId, new Date(`${date}T12:00:00Z`).getUTCDay()]),
    db.query("SELECT data_hora, duracao_min FROM agendamentos WHERE colaborador_id = ? AND status IN ('confirmado','pendente') AND data_hora < ? AND DATE_ADD(data_hora, INTERVAL duracao_min MINUTE) > ?", [professionalId, `${next} 00:00:00`, `${date} 00:00:00`]),
    db.query('SELECT data_hora_ini, data_hora_fim FROM horarios_bloqueados WHERE colaborador_id = ? AND data_hora_ini < ? AND data_hora_fim > ?', [professionalId, `${next} 00:00:00`, `${date} 00:00:00`]),
  ]);
  const busy = [
    ...appointments.map(a => [+parseLocal(a.data_hora), +parseLocal(a.data_hora) + Number(a.duracao_min) * 60000]),
    ...blocks.map(b => [+parseLocal(b.data_hora_ini), +parseLocal(b.data_hora_fim)]),
  ];
  const slots = new Set();
  for (const shift of working) {
    const end = +parseLocal(`${date} ${shift.hora_fim}`);
    for (let start = +parseLocal(`${date} ${shift.hora_inicio}`); start + duration * 60000 <= end; start += 1800000) {
      if (start > +now && busy.every(([from, until]) => start >= until || start + duration * 60000 <= from)) slots.add(formatLocal(new Date(start)).slice(11, 16));
    }
  }
  return [...slots].sort();
}
module.exports = { parseLocal, formatLocal, nextDate, availableSlots };
