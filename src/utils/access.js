const { pool } = require('../config/database');

async function obterColaboradorAcessivel(usuario, colaboradorId) {
  const id = Number.parseInt(colaboradorId, 10);
  if (!Number.isInteger(id) || id <= 0) return null;

  const params = [id];
  let filtro = '';
  if (usuario.role === 'admin') {
    filtro = ` AND c.barbearia_id IN (
      SELECT administrador.barbearia_id FROM colaboradores administrador
      WHERE administrador.usuario_id = ? AND administrador.ativo = 1
    )`;
    params.push(usuario.id);
  } else {
    filtro = ' AND c.usuario_id = ?';
    params.push(usuario.id);
  }

  const [rows] = await pool.query(
    `SELECT c.id, c.usuario_id, c.barbearia_id
       FROM colaboradores c
       JOIN usuarios u ON u.id = c.usuario_id
      WHERE c.id = ? AND c.ativo = 1 AND u.ativo = 1${filtro}
      LIMIT 1`,
    params,
  );
  return rows[0] || null;
}

async function obterColaboradorDoUsuario(usuarioId) {
  const [rows] = await pool.query(
    `SELECT c.id, c.usuario_id, c.barbearia_id
       FROM colaboradores c
      WHERE c.usuario_id = ? AND c.ativo = 1
      LIMIT 1`,
    [usuarioId],
  );
  return rows[0] || null;
}

async function obterBarbeariaAdministrada(usuarioId, barbeariaId) {
  const id = Number.parseInt(barbeariaId, 10);
  if (!Number.isInteger(id) || id <= 0) return null;
  const [rows] = await pool.query(
    `SELECT b.id
       FROM barbearias b
      WHERE b.id = ? AND b.ativa = 1
        AND (b.admin_id = ? OR EXISTS (
          SELECT 1 FROM colaboradores c
           WHERE c.barbearia_id = b.id AND c.usuario_id = ? AND c.ativo = 1
        ))
      LIMIT 1`,
    [id, usuarioId, usuarioId],
  );
  return rows[0] || null;
}

async function obterServicoAdministravel(usuarioId, servicoId) {
  const id = Number.parseInt(servicoId, 10);
  if (!Number.isInteger(id) || id <= 0) return null;
  const [rows] = await pool.query(
    `SELECT s.id, s.barbearia_id
       FROM servicos s
       JOIN barbearias b ON b.id = s.barbearia_id
      WHERE s.id = ? AND (b.admin_id = ? OR EXISTS (
        SELECT 1 FROM colaboradores c
         WHERE c.barbearia_id = b.id AND c.usuario_id = ? AND c.ativo = 1
      )) LIMIT 1`,
    [id, usuarioId, usuarioId],
  );
  return rows[0] || null;
}

module.exports = {
  obterColaboradorAcessivel,
  obterColaboradorDoUsuario,
  obterBarbeariaAdministrada,
  obterServicoAdministravel,
};
