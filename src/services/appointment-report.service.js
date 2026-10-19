const STATUS_ATIVOS = new Set(['pendente', 'confirmado']);

function normalizarStatus(status) {
  return String(status || '').trim().toLowerCase();
}

function centavos(valor) {
  const texto = String(valor ?? '0').replace(',', '.');
  const numero = Number(texto);
  return Number.isFinite(numero) ? Math.round(numero * 100) : 0;
}

function moeda(valorCentavos) {
  return (valorCentavos / 100).toFixed(2);
}

function calcularRelatorio(appointments) {
  const unique = new Map();
  for (const appointment of appointments || []) unique.set(String(appointment.id), appointment);
  const atendimentos = [...unique.values()].sort((a, b) => String(a.data_hora).localeCompare(String(b.data_hora)) || Number(a.id) - Number(b.id));
  const status = item => normalizarStatus(item.status);
  const concluidos = atendimentos.filter(item => status(item) === 'concluido');
  const cancelados = atendimentos.filter(item => status(item) === 'cancelado');
  const pendentes = atendimentos.filter(item => !['concluido', 'cancelado'].includes(status(item)));
  const valor = item => centavos(item.valor_cobrado);
  const valorRealizadoCentavos = concluidos.reduce((sum, item) => sum + valor(item), 0);
  const valorAgendadoCentavos = atendimentos.filter(item => status(item) !== 'cancelado').reduce((sum, item) => sum + valor(item), 0);
  const percentual = (part, total) => total ? ((part * 100) / total).toFixed(1) : '0.0';
  const groupBy = key => {
    const groups = new Map();
    for (const item of atendimentos) {
      const groupKey = String(item[key]);
      if (!groups.has(groupKey)) groups.set(groupKey, []);
      groups.get(groupKey).push(item);
    }
    return [...groups.values()];
  };
  const totaisPorProfissional = groupBy('profissional_id').map(group => {
    const done = group.filter(item => status(item) === 'concluido');
    const doneCents = done.reduce((sum, item) => sum + valor(item), 0);
    return {
      profissional_id: group[0].profissional_id,
      barbeiro: group[0].barbeiro,
      total: group.length,
      concluidos: done.length,
      cancelados: group.filter(item => status(item) === 'cancelado').length,
      pendentes: group.filter(item => !['concluido', 'cancelado'].includes(status(item))).length,
      valor_realizado: moeda(doneCents),
      ticket_medio: moeda(done.length ? Math.round(doneCents / done.length) : 0),
      minutos_ocupados: done.reduce((sum, item) => sum + Number(item.duracao_min || 0), 0),
    };
  }).sort((a, b) => b.concluidos - a.concluidos || String(a.barbeiro).localeCompare(String(b.barbeiro)));
  const totaisPorServico = groupBy('servico_id').map(group => {
    const done = group.filter(item => status(item) === 'concluido');
    const doneCents = done.reduce((sum, item) => sum + valor(item), 0);
    return {
      servico_id: group[0].servico_id,
      servico: group[0].servico,
      total: group.length,
      concluidos: done.length,
      valor_realizado: moeda(doneCents),
      percentual_total_concluidos: percentual(done.length, concluidos.length),
    };
  }).sort((a, b) => b.concluidos - a.concluidos || String(a.servico).localeCompare(String(b.servico)));
  const horas = new Map();
  for (const item of concluidos) {
    const hour = Number(String(item.data_hora).slice(11, 13));
    if (Number.isInteger(hour)) horas.set(hour, (horas.get(hour) || 0) + 1);
  }
  const pico = [...horas.entries()].sort((a, b) => b[1] - a[1] || a[0] - b[0])[0];
  return {
    total_agendamentos: atendimentos.length,
    total_concluidos: concluidos.length,
    total_cancelados: cancelados.length,
    total_pendentes: pendentes.length,
    valor_agendado: moeda(valorAgendadoCentavos),
    valor_realizado: moeda(valorRealizadoCentavos),
    total_geral: moeda(valorRealizadoCentavos),
    ticket_medio: moeda(concluidos.length ? Math.round(valorRealizadoCentavos / concluidos.length) : 0),
    taxa_conclusao: percentual(concluidos.length, atendimentos.length),
    taxa_cancelamento: percentual(cancelados.length, atendimentos.length),
    duracao_total_realizada: concluidos.reduce((sum, item) => sum + Number(item.duracao_min || 0), 0),
    pico_hora: pico ? pico[0] : null,
    totais_por_profissional: totaisPorProfissional,
    totais_por_servico: totaisPorServico,
    atendimentos,
  };
}

module.exports = { calcularRelatorio, normalizarStatus, STATUS_ATIVOS };
