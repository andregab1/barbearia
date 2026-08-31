const crypto = require('crypto');

function requestContext(req, res, next) {
  const received = String(req.headers['x-request-id'] || '').trim();
  req.requestId = /^[a-zA-Z0-9._-]{8,80}$/.test(received) ? received : crypto.randomUUID();
  res.setHeader('X-Request-Id', req.requestId);
  next();
}

function errorBody(req, code, message, fields) {
  const body = { code, message, requestId: req.requestId };
  if (fields && Object.keys(fields).length > 0) body.fields = fields;
  return body;
}

module.exports = { requestContext, errorBody };
