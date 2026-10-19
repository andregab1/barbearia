class FiscalProvider {
  async issueInvoice() { throw new Error('FISCAL_PROVIDER_NOT_IMPLEMENTED'); }
  async cancelInvoice() { throw new Error('FISCAL_PROVIDER_NOT_IMPLEMENTED'); }
  async getInvoice() { throw new Error('FISCAL_PROVIDER_NOT_IMPLEMENTED'); }
  async downloadPdf() { throw new Error('FISCAL_PROVIDER_NOT_IMPLEMENTED'); }
  async downloadXml() { throw new Error('FISCAL_PROVIDER_NOT_IMPLEMENTED'); }
}

module.exports = FiscalProvider;
