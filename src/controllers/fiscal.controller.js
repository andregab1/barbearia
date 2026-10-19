const { pool } = require('../config/database');
const { errorBody } = require('../middlewares/request.middleware');
const { requestInvoice } = require('../services/fiscal.service');

async function getSettings(req, res, next) {
  try {
    const [rows] = await pool.query(
      `SELECT razao_social, nome_fantasia, cnpj, inscricao_municipal, municipio, uf,
              regime_tributario, codigo_servico, aliquota, ambiente, provedor,
              emissao_automatica, ativo
         FROM fiscal_settings WHERE barbearia_id = ?`, [req.tenant.id],
    );
    return res.json({ data: rows[0] || null, requestId: req.requestId });
  } catch (error) { return next(error); }
}

async function updateSettings(req, res, next) {
  const data = req.body || {};
  const cnpj = data.cnpj == null ? null : String(data.cnpj).replace(/\D/g, '');
  if (cnpj && cnpj.length !== 14) return res.status(422).json(errorBody(req, 'INVALID_CNPJ', 'CNPJ deve conter 14 dígitos.'));
  const fields = ['razao_social','nome_fantasia','inscricao_municipal','municipio','regime_tributario','codigo_servico','provedor'];
  if (fields.some((field) => data[field] != null && String(data[field]).length > 180)) return res.status(422).json(errorBody(req, 'VALIDATION_ERROR', 'Configuração fiscal inválida.'));
  const uf = data.uf == null ? null : String(data.uf).toUpperCase();
  if (uf && !/^[A-Z]{2}$/.test(uf)) return res.status(422).json(errorBody(req, 'INVALID_UF', 'UF inválida.'));
  try {
    await pool.query(
      `INSERT INTO fiscal_settings
         (barbearia_id, razao_social, nome_fantasia, cnpj, inscricao_municipal, municipio, uf,
          regime_tributario, codigo_servico, aliquota, ambiente, provedor, emissao_automatica, ativo)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE razao_social=VALUES(razao_social), nome_fantasia=VALUES(nome_fantasia),
         cnpj=VALUES(cnpj), inscricao_municipal=VALUES(inscricao_municipal), municipio=VALUES(municipio),
         uf=VALUES(uf), regime_tributario=VALUES(regime_tributario), codigo_servico=VALUES(codigo_servico),
         aliquota=VALUES(aliquota), ambiente=VALUES(ambiente), provedor=VALUES(provedor),
         emissao_automatica=VALUES(emissao_automatica), ativo=VALUES(ativo)`,
      [req.tenant.id, data.razao_social || null, data.nome_fantasia || null, cnpj,
        data.inscricao_municipal || null, data.municipio || null, uf, data.regime_tributario || null,
        data.codigo_servico || null, data.aliquota || null, data.ambiente === 'production' ? 'production' : 'sandbox',
        data.provedor || null, data.emissao_automatica ? 1 : 0, data.ativo ? 1 : 0],
    );
    return res.json({ message: 'Configuração fiscal salva.', requestId: req.requestId });
  } catch (error) { return next(error); }
}

async function documents(req, res, next) {
  try {
    const [rows] = await pool.query(
      `SELECT fd.id, fd.agendamento_id appointment_id, fd.status, fd.document_type,
              fd.provider, fd.provider_document_id, fd.total_amount, fd.tax_amount,
              fd.issued_at, fd.cancelled_at, fd.error_message, fd.criado_em created_at,
              u.nome client
         FROM fiscal_documents fd JOIN usuarios u ON u.id = fd.cliente_id
        WHERE fd.barbearia_id = ? ORDER BY fd.id DESC LIMIT 100`, [req.tenant.id],
    );
    return res.json({ data: rows, requestId: req.requestId });
  } catch (error) { return next(error); }
}

async function issue(req, res, next) {
  try {
    const result = await requestInvoice({ tenantId: req.tenant.id, actorId: req.usuario.id,
      appointmentId: Number.parseInt(req.body.appointment_id, 10), idempotencyKey: req.headers['x-idempotency-key'] });
    if (result.status >= 400) return res.status(result.status).json(errorBody(req, result.code, 'Documento fiscal não pôde ser solicitado.'));
    return res.status(result.status).json({ data: { id: result.id, status: result.documentStatus }, idempotent: !!result.idempotent, requestId: req.requestId });
  } catch (error) { return next(error); }
}

module.exports = { getSettings, updateSettings, documents, issue };
