require 'rails_helper'

describe Stock::Operation::LoadUniteLegale, vcr: { cassette_name: 'data_gouv_sirene_july_OK' } do
  subject { described_class.call logger: logger }

  let(:logger) { instance_spy Logger }
  let(:expected_uri) { 'http://files.data.gouv.fr/insee-sirene/StockUniteLegale_utf8.zip' }

  context 'when remote stock is importable (newer)' do
    before { create :stock_unite_legale, :of_june, :completed }

    it { is_expected.to be_success }

    it 'logs import will start' do
      subject
      expect(logger)
        .to have_received(:info)
        .with("New stock found 07, will import...")
    end

    it 'shedule a new ImportStockJob' do
      expect { subject }
        .to have_enqueued_job(ImportStockJob)
        .on_queue('sirene_api_test_stock')
    end

    it 'persist a new stock to import' do
      expect { subject }.to change(StockUniteLegale, :count).by(1)
    end

    its([:remote_stock]) { is_expected.to be_persisted }
    its([:remote_stock]) { is_expected.to have_attributes(uri: expected_uri, status: 'PENDING', month: '07', year: '2019') }
  end

  context 'when remote stock is not importable (same)' do
    before { create :stock_unite_legale, :of_july, :completed }

    it { is_expected.to be_failure }

    it 'logs a warning' do
      subject
      expect(logger)
        .to have_received(:warn)
        .with('Remote stock not importable (remote month: 07, current (COMPLETED) month: 07)')
    end

    its([:remote_stock]) { is_expected.not_to be_persisted }

    it 'does not enqueue job' do
      expect { subject }
        .not_to have_enqueued_job ImportStockJob
    end
  end

  describe 'Integration: from download to import', :perform_enqueued_jobs do
    let(:stock_model) { StockUniteLegale }
    let(:imported_month) { '07' }
    let(:expected_sirens) { ['000325175', '001807254', '005410220'] }

    let(:expected_tmp_file) do
      Rails.root.join 'tmp', 'files', 'sample_unites_legales.csv'
    end

    let(:mocked_downloaded_file) do
      Rails.root.join('spec', 'fixtures', 'sample_unites_legales.csv.zip').to_s
    end

    it_behaves_like 'importing csv'
  end
end
