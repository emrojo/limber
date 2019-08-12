# frozen_string_literal: true

RSpec.describe Utility::NormalisedBinningCalculator do
  context 'when computing values for normalised binning' do
    let(:assay_version) { 'v1.0' }
    let(:parent_uuid) { 'example-plate-uuid' }
    let(:plate_size) { 96 }
    let(:num_rows) { 8 }
    let(:num_cols) { 12 }

    let(:well_a1) do
      create(:v2_well,
             position: { 'name' => 'A1' },
             qc_results: create_list(:qc_result_concentration, 1, value: 1.0))
    end
    let(:well_b1) do
      create(:v2_well,
             position: { 'name' => 'B1' },
             qc_results: create_list(:qc_result_concentration, 1, value: 56.0))
    end
    let(:well_c1) do
      create(:v2_well,
             position: { 'name' => 'C1' },
             qc_results: create_list(:qc_result_concentration, 1, value: 3.5))
    end
    let(:well_d1) do
      create(:v2_well,
             position: { 'name' => 'D1' },
             qc_results: create_list(:qc_result_concentration, 1, value: 1.8))
    end

    let(:parent_plate) do
      create :v2_plate,
             uuid: parent_uuid,
             barcode_number: '2',
             size: plate_size,
             wells: [well_a1, well_b1, well_c1, well_d1],
             outer_requests: requests
    end

    let(:requests) { Array.new(4) { |i| create :library_request, state: 'started', uuid: "request-#{i}" } }

    let(:dilutions_config) do
      {
        'target_amount_ng' => 50,
        'target_volume' => 20,
        'minimum_source_volume' => 0.2,
        'bins' => [
          { 'colour' => 1, 'pcr_cycles' => 16, 'max' => 25 },
          { 'colour' => 2, 'pcr_cycles' => 14, 'min' => 25 }
        ]
      }
    end

    subject { Utility::NormalisedBinningCalculator.new(dilutions_config) }

    describe '#normalisation_details' do
      it 'calculates normalisation details correctly' do
        expected_norm_details = {
          'A1' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                    'amount_in_target' => BigDecimal('20.0'), 'dest_conc' => BigDecimal('1.0') },
          'B1' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                    'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
          'C1' => { 'vol_source_reqd' => BigDecimal('14.286'), 'vol_diluent_reqd' => BigDecimal('5.714'),
                    'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
          'D1' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                    'amount_in_target' => BigDecimal('36.0'), 'dest_conc' => BigDecimal('1.8') }
        }

        expect(subject.normalisation_details(parent_plate)).to eq(expected_norm_details)
      end
    end

    describe '#compute_vol_source_reqd' do
      context 'when sample concentration is within range' do
        let(:sample_conc) { 50.0 }

        it 'returns expected volume' do
          expect(subject.compute_vol_source_reqd(sample_conc)).to eq(1.0)
        end
      end

      context 'when sample concentration is zero' do
        let(:sample_conc) { 0.0 }

        it 'returns the maximum volume' do
          expect(subject.compute_vol_source_reqd(sample_conc)).to eq(20.0)
        end
      end

      context 'when sample concentration is below range minimum' do
        let(:sample_conc) { 2.0 }

        it 'returns the maximum volume' do
          expect(subject.compute_vol_source_reqd(sample_conc)).to eq(20.0)
        end
      end

      context 'when sample concentration is above range maximum' do
        let(:sample_conc) { 500.0 }

        it 'returns the minimum volume' do
          expect(subject.compute_vol_source_reqd(sample_conc)).to eq(0.2)
        end
      end
    end

    describe '#compute_well_transfers' do
      context 'for a simple example with few wells' do
        let(:expd_transfers_simple) do
          {
            'A1' => { 'dest_locn' => 'A1', 'dest_conc' => BigDecimal('1.0'), 'volume' => BigDecimal('20.0') },
            'B1' => { 'dest_locn' => 'A2', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'C1' => { 'dest_locn' => 'B2', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('14.286') },
            'D1' => { 'dest_locn' => 'C2', 'dest_conc' => BigDecimal('1.8'), 'volume' => BigDecimal('20.0') }
          }
        end

        it 'creates the correct transfers' do
          expect(subject.compute_well_transfers(parent_plate)).to eq(expd_transfers_simple)
        end
      end

      context 'when all wells fall in the same bin' do
        let(:well_a1) do
          create(:v2_well,
                 position: { 'name' => 'A1' },
                 qc_results: create_list(:qc_result_concentration, 1, value: 3.5))
        end
        let(:well_b1) do
          create(:v2_well,
                 position: { 'name' => 'B1' },
                 qc_results: create_list(:qc_result_concentration, 1, value: 3.5))
        end
        let(:well_d1) do
          create(:v2_well,
                 position: { 'name' => 'D1' },
                 qc_results: create_list(:qc_result_concentration, 1, value: 3.5))
        end
        let(:expd_transfers_same_bin) do
          {
            'A1' => { 'dest_locn' => 'A1', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('14.286') },
            'B1' => { 'dest_locn' => 'B1', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('14.286') },
            'C1' => { 'dest_locn' => 'C1', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('14.286') },
            'D1' => { 'dest_locn' => 'D1', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('14.286') }
          }
        end

        it 'creates the correct transfers' do
          expect(subject.compute_well_transfers(parent_plate)).to eq(expd_transfers_same_bin)
        end
      end
    end

    describe '#compute_well_transfers_hash' do
      context 'when bins span multiple columns' do
        let(:normalisation_details) do
          {
            'A1' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('20.0'), 'dest_conc' => BigDecimal('1.0') },
            'B1' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                      'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'C1' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                      'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'D1' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                      'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'E1' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                      'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'F1' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                      'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'G1' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                      'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'H1' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                      'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'A2' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                      'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'B2' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                      'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'C2' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                      'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'D2' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                      'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'E2' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                      'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'F2' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                      'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'G2' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                      'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'H2' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                      'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'A3' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                      'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') }
          }
        end
        let(:expd_transfers_mult_cols) do
          {
            'A1' => { 'dest_locn' => 'A1', 'dest_conc' => BigDecimal('1.0'), 'volume' => BigDecimal('20.0') },
            'B1' => { 'dest_locn' => 'A2', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'C1' => { 'dest_locn' => 'B2', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'D1' => { 'dest_locn' => 'C2', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'E1' => { 'dest_locn' => 'D2', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'F1' => { 'dest_locn' => 'E2', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'G1' => { 'dest_locn' => 'F2', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'H1' => { 'dest_locn' => 'G2', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'A2' => { 'dest_locn' => 'H2', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'B2' => { 'dest_locn' => 'A3', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'C2' => { 'dest_locn' => 'B3', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'D2' => { 'dest_locn' => 'C3', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'E2' => { 'dest_locn' => 'D3', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'F2' => { 'dest_locn' => 'E3', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'G2' => { 'dest_locn' => 'F3', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'H2' => { 'dest_locn' => 'G3', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'A3' => { 'dest_locn' => 'H3', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') }
          }
        end

        it 'creates the correct transfers' do
          expect(subject.compute_well_transfers_hash(normalisation_details, num_rows, num_cols))
            .to eq(expd_transfers_mult_cols)
        end
      end

      context 'when requiring compression due to numbers of wells' do
        let(:normalisation_details) do
          {
            'A1' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('20.0'), 'dest_conc' => BigDecimal('1.0') },
            'B1' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('20.0'), 'dest_conc' => BigDecimal('1.0') },
            'C1' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('20.0'), 'dest_conc' => BigDecimal('1.0') },
            'D1' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('20.0'), 'dest_conc' => BigDecimal('1.0') },
            'E1' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('20.0'), 'dest_conc' => BigDecimal('1.0') },
            'F1' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('20.0'), 'dest_conc' => BigDecimal('1.0') },
            'G1' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('20.0'), 'dest_conc' => BigDecimal('1.0') },
            'H1' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('20.0'), 'dest_conc' => BigDecimal('1.0') },
            'A2' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('20.0'), 'dest_conc' => BigDecimal('1.0') },
            'B2' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('20.0'), 'dest_conc' => BigDecimal('1.0') },
            'C2' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('20.0'), 'dest_conc' => BigDecimal('1.0') },
            'D2' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('20.0'), 'dest_conc' => BigDecimal('1.0') },
            'E2' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('20.0'), 'dest_conc' => BigDecimal('1.0') },
            'F2' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('20.0'), 'dest_conc' => BigDecimal('1.0') },
            'G2' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('20.0'), 'dest_conc' => BigDecimal('1.0') },
            'H2' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('20.0'), 'dest_conc' => BigDecimal('1.0') },
            'A3' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('20.0'), 'dest_conc' => BigDecimal('1.0') },
            'B3' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('20.0'), 'dest_conc' => BigDecimal('1.0') },
            'C3' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('20.0'), 'dest_conc' => BigDecimal('1.0') },
            'D3' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('20.0'), 'dest_conc' => BigDecimal('1.0') },
            'E3' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('20.0'), 'dest_conc' => BigDecimal('1.0') },
            'F3' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('20.0'), 'dest_conc' => BigDecimal('1.0') },
            'G3' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('20.0'), 'dest_conc' => BigDecimal('1.0') },
            'H3' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('20.0'), 'dest_conc' => BigDecimal('1.0') },
            'A4' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('20.0'), 'dest_conc' => BigDecimal('1.0') },
            'B4' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('20.0'), 'dest_conc' => BigDecimal('1.0') },
            'C4' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('20.0'), 'dest_conc' => BigDecimal('1.0') },
            'D4' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('20.0'), 'dest_conc' => BigDecimal('1.0') },
            'E4' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('20.0'), 'dest_conc' => BigDecimal('1.0') },
            'F4' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('20.0'), 'dest_conc' => BigDecimal('1.0') },
            'G4' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('20.0'), 'dest_conc' => BigDecimal('1.0') },
            'H4' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('20.0'), 'dest_conc' => BigDecimal('1.0') },
            'A5' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('20.0'), 'dest_conc' => BigDecimal('1.0') },
            'B5' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('20.0'), 'dest_conc' => BigDecimal('1.0') },
            'C5' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('20.0'), 'dest_conc' => BigDecimal('1.0') },
            'D5' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('20.0'), 'dest_conc' => BigDecimal('1.0') },
            'E5' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('20.0'), 'dest_conc' => BigDecimal('1.0') },
            'F5' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('20.0'), 'dest_conc' => BigDecimal('1.0') },
            'G5' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('20.0'), 'dest_conc' => BigDecimal('1.0') },
            'H5' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('20.0'), 'dest_conc' => BigDecimal('1.0') },
            'A6' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('20.0'), 'dest_conc' => BigDecimal('1.0') },
            'B6' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('20.0'), 'dest_conc' => BigDecimal('1.0') },
            'C6' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('20.0'), 'dest_conc' => BigDecimal('1.0') },
            'D6' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('20.0'), 'dest_conc' => BigDecimal('1.0') },
            'E6' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('20.0'), 'dest_conc' => BigDecimal('1.0') },
            'F6' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                      'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'G6' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                      'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'H6' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                      'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'A7' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                      'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'B7' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                      'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'C7' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                      'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'D7' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                      'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'E7' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                      'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'F7' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                      'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'G7' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                      'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'H7' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                      'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'A8' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                      'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'B8' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                      'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'C8' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                      'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'D8' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                      'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'E8' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                      'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'F8' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                      'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'G8' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                      'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'H8' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                      'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'A9' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                      'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'B9' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                      'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'C9' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                      'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'D9' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                      'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'E9' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                      'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'F9' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                      'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'G9' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                      'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'H9' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                      'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'A10' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                       'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'B10' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                       'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'C10' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                       'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'D10' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                       'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'E10' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                       'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'F10' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                       'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'G10' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                       'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'H10' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                       'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'A11' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                       'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'B11' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                       'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'C11' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                       'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'D11' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                       'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'E11' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                       'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'F11' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                       'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'G11' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                       'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'H11' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                       'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'A12' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                       'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'B12' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                       'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'C12' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                       'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'D12' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                       'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'E12' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                       'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'F12' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                       'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'G12' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                       'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') },
            'H12' => { 'vol_source_reqd' => BigDecimal('0.893'), 'vol_diluent_reqd' => BigDecimal('19.107'),
                       'amount_in_target' => BigDecimal('50.0'), 'dest_conc' => BigDecimal('2.5') }
          }
        end
        let(:expd_transfers_comp_many_wells) do
          {
            'A1' => { 'dest_locn' => 'A1', 'dest_conc' => BigDecimal('1.0'), 'volume' => BigDecimal('20.0') },
            'B1' => { 'dest_locn' => 'B1', 'dest_conc' => BigDecimal('1.0'), 'volume' => BigDecimal('20.0') },
            'C1' => { 'dest_locn' => 'C1', 'dest_conc' => BigDecimal('1.0'), 'volume' => BigDecimal('20.0') },
            'D1' => { 'dest_locn' => 'D1', 'dest_conc' => BigDecimal('1.0'), 'volume' => BigDecimal('20.0') },
            'E1' => { 'dest_locn' => 'E1', 'dest_conc' => BigDecimal('1.0'), 'volume' => BigDecimal('20.0') },
            'F1' => { 'dest_locn' => 'F1', 'dest_conc' => BigDecimal('1.0'), 'volume' => BigDecimal('20.0') },
            'G1' => { 'dest_locn' => 'G1', 'dest_conc' => BigDecimal('1.0'), 'volume' => BigDecimal('20.0') },
            'H1' => { 'dest_locn' => 'H1', 'dest_conc' => BigDecimal('1.0'), 'volume' => BigDecimal('20.0') },
            'A2' => { 'dest_locn' => 'A2', 'dest_conc' => BigDecimal('1.0'), 'volume' => BigDecimal('20.0') },
            'B2' => { 'dest_locn' => 'B2', 'dest_conc' => BigDecimal('1.0'), 'volume' => BigDecimal('20.0') },
            'C2' => { 'dest_locn' => 'C2', 'dest_conc' => BigDecimal('1.0'), 'volume' => BigDecimal('20.0') },
            'D2' => { 'dest_locn' => 'D2', 'dest_conc' => BigDecimal('1.0'), 'volume' => BigDecimal('20.0') },
            'E2' => { 'dest_locn' => 'E2', 'dest_conc' => BigDecimal('1.0'), 'volume' => BigDecimal('20.0') },
            'F2' => { 'dest_locn' => 'F2', 'dest_conc' => BigDecimal('1.0'), 'volume' => BigDecimal('20.0') },
            'G2' => { 'dest_locn' => 'G2', 'dest_conc' => BigDecimal('1.0'), 'volume' => BigDecimal('20.0') },
            'H2' => { 'dest_locn' => 'H2', 'dest_conc' => BigDecimal('1.0'), 'volume' => BigDecimal('20.0') },
            'A3' => { 'dest_locn' => 'A3', 'dest_conc' => BigDecimal('1.0'), 'volume' => BigDecimal('20.0') },
            'B3' => { 'dest_locn' => 'B3', 'dest_conc' => BigDecimal('1.0'), 'volume' => BigDecimal('20.0') },
            'C3' => { 'dest_locn' => 'C3', 'dest_conc' => BigDecimal('1.0'), 'volume' => BigDecimal('20.0') },
            'D3' => { 'dest_locn' => 'D3', 'dest_conc' => BigDecimal('1.0'), 'volume' => BigDecimal('20.0') },
            'E3' => { 'dest_locn' => 'E3', 'dest_conc' => BigDecimal('1.0'), 'volume' => BigDecimal('20.0') },
            'F3' => { 'dest_locn' => 'F3', 'dest_conc' => BigDecimal('1.0'), 'volume' => BigDecimal('20.0') },
            'G3' => { 'dest_locn' => 'G3', 'dest_conc' => BigDecimal('1.0'), 'volume' => BigDecimal('20.0') },
            'H3' => { 'dest_locn' => 'H3', 'dest_conc' => BigDecimal('1.0'), 'volume' => BigDecimal('20.0') },
            'A4' => { 'dest_locn' => 'A4', 'dest_conc' => BigDecimal('1.0'), 'volume' => BigDecimal('20.0') },
            'B4' => { 'dest_locn' => 'B4', 'dest_conc' => BigDecimal('1.0'), 'volume' => BigDecimal('20.0') },
            'C4' => { 'dest_locn' => 'C4', 'dest_conc' => BigDecimal('1.0'), 'volume' => BigDecimal('20.0') },
            'D4' => { 'dest_locn' => 'D4', 'dest_conc' => BigDecimal('1.0'), 'volume' => BigDecimal('20.0') },
            'E4' => { 'dest_locn' => 'E4', 'dest_conc' => BigDecimal('1.0'), 'volume' => BigDecimal('20.0') },
            'F4' => { 'dest_locn' => 'F4', 'dest_conc' => BigDecimal('1.0'), 'volume' => BigDecimal('20.0') },
            'G4' => { 'dest_locn' => 'G4', 'dest_conc' => BigDecimal('1.0'), 'volume' => BigDecimal('20.0') },
            'H4' => { 'dest_locn' => 'H4', 'dest_conc' => BigDecimal('1.0'), 'volume' => BigDecimal('20.0') },
            'A5' => { 'dest_locn' => 'A5', 'dest_conc' => BigDecimal('1.0'), 'volume' => BigDecimal('20.0') },
            'B5' => { 'dest_locn' => 'B5', 'dest_conc' => BigDecimal('1.0'), 'volume' => BigDecimal('20.0') },
            'C5' => { 'dest_locn' => 'C5', 'dest_conc' => BigDecimal('1.0'), 'volume' => BigDecimal('20.0') },
            'D5' => { 'dest_locn' => 'D5', 'dest_conc' => BigDecimal('1.0'), 'volume' => BigDecimal('20.0') },
            'E5' => { 'dest_locn' => 'E5', 'dest_conc' => BigDecimal('1.0'), 'volume' => BigDecimal('20.0') },
            'F5' => { 'dest_locn' => 'F5', 'dest_conc' => BigDecimal('1.0'), 'volume' => BigDecimal('20.0') },
            'G5' => { 'dest_locn' => 'G5', 'dest_conc' => BigDecimal('1.0'), 'volume' => BigDecimal('20.0') },
            'H5' => { 'dest_locn' => 'H5', 'dest_conc' => BigDecimal('1.0'), 'volume' => BigDecimal('20.0') },
            'A6' => { 'dest_locn' => 'A6', 'dest_conc' => BigDecimal('1.0'), 'volume' => BigDecimal('20.0') },
            'B6' => { 'dest_locn' => 'B6', 'dest_conc' => BigDecimal('1.0'), 'volume' => BigDecimal('20.0') },
            'C6' => { 'dest_locn' => 'C6', 'dest_conc' => BigDecimal('1.0'), 'volume' => BigDecimal('20.0') },
            'D6' => { 'dest_locn' => 'D6', 'dest_conc' => BigDecimal('1.0'), 'volume' => BigDecimal('20.0') },
            'E6' => { 'dest_locn' => 'E6', 'dest_conc' => BigDecimal('1.0'), 'volume' => BigDecimal('20.0') },
            'F6' => { 'dest_locn' => 'F6', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'G6' => { 'dest_locn' => 'G6', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'H6' => { 'dest_locn' => 'H6', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'A7' => { 'dest_locn' => 'A7', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'B7' => { 'dest_locn' => 'B7', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'C7' => { 'dest_locn' => 'C7', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'D7' => { 'dest_locn' => 'D7', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'E7' => { 'dest_locn' => 'E7', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'F7' => { 'dest_locn' => 'F7', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'G7' => { 'dest_locn' => 'G7', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'H7' => { 'dest_locn' => 'H7', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'A8' => { 'dest_locn' => 'A8', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'B8' => { 'dest_locn' => 'B8', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'C8' => { 'dest_locn' => 'C8', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'D8' => { 'dest_locn' => 'D8', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'E8' => { 'dest_locn' => 'E8', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'F8' => { 'dest_locn' => 'F8', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'G8' => { 'dest_locn' => 'G8', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'H8' => { 'dest_locn' => 'H8', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'A9' => { 'dest_locn' => 'A9', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'B9' => { 'dest_locn' => 'B9', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'C9' => { 'dest_locn' => 'C9', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'D9' => { 'dest_locn' => 'D9', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'E9' => { 'dest_locn' => 'E9', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'F9' => { 'dest_locn' => 'F9', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'G9' => { 'dest_locn' => 'G9', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'H9' => { 'dest_locn' => 'H9', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'A10' => { 'dest_locn' => 'A10', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'B10' => { 'dest_locn' => 'B10', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'C10' => { 'dest_locn' => 'C10', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'D10' => { 'dest_locn' => 'D10', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'E10' => { 'dest_locn' => 'E10', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'F10' => { 'dest_locn' => 'F10', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'G10' => { 'dest_locn' => 'G10', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'H10' => { 'dest_locn' => 'H10', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'A11' => { 'dest_locn' => 'A11', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'B11' => { 'dest_locn' => 'B11', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'C11' => { 'dest_locn' => 'C11', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'D11' => { 'dest_locn' => 'D11', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'E11' => { 'dest_locn' => 'E11', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'F11' => { 'dest_locn' => 'F11', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'G11' => { 'dest_locn' => 'G11', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'H11' => { 'dest_locn' => 'H11', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'A12' => { 'dest_locn' => 'A12', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'B12' => { 'dest_locn' => 'B12', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'C12' => { 'dest_locn' => 'C12', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'D12' => { 'dest_locn' => 'D12', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'E12' => { 'dest_locn' => 'E12', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'F12' => { 'dest_locn' => 'F12', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'G12' => { 'dest_locn' => 'G12', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') },
            'H12' => { 'dest_locn' => 'H12', 'dest_conc' => BigDecimal('2.5'), 'volume' => BigDecimal('0.893') }
          }
        end

        it 'creates the correct transfers' do
          expect(subject.compute_well_transfers_hash(normalisation_details, num_rows, num_cols))
            .to eq(expd_transfers_comp_many_wells)
        end
      end

      context 'with many bins defined requiring compression' do
        let(:dilutions_config) do
          {
            'target_amount_ng' => 200,
            'target_volume' => 20,
            'minimum_source_volume' => 0.2,
            'bins' => [
              { 'colour' => 1, 'pcr_cycles' => 20, 'max' => 10 },
              { 'colour' => 2, 'pcr_cycles' => 19, 'min' => 10, 'max' => 20 },
              { 'colour' => 3, 'pcr_cycles' => 18, 'min' => 20, 'max' => 30 },
              { 'colour' => 4, 'pcr_cycles' => 17, 'min' => 30, 'max' => 40 },
              { 'colour' => 5, 'pcr_cycles' => 16, 'min' => 40, 'max' => 50 },
              { 'colour' => 6, 'pcr_cycles' => 15, 'min' => 50, 'max' => 60 },
              { 'colour' => 7, 'pcr_cycles' => 14, 'min' => 60, 'max' => 70 },
              { 'colour' => 8, 'pcr_cycles' => 13, 'min' => 70, 'max' => 80 },
              { 'colour' => 9, 'pcr_cycles' => 12, 'min' => 80, 'max' => 90 },
              { 'colour' => 10, 'pcr_cycles' => 11, 'min' => 90, 'max' => 100 },
              { 'colour' => 11, 'pcr_cycles' => 10, 'min' => 100, 'max' => 110 },
              { 'colour' => 12, 'pcr_cycles' => 9, 'min' => 110, 'max' => 120 },
              { 'colour' => 13, 'pcr_cycles' => 8, 'min' => 120 }
            ]
          }
        end
        let(:normalisation_details) do
          {
            'A1' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('1.0'), 'dest_conc' => BigDecimal('0.05') },
            'B1' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('11.0'), 'dest_conc' => BigDecimal('0.55') },
            'C1' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('21.0'), 'dest_conc' => BigDecimal('1.05') },
            'D1' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('31.0'), 'dest_conc' => BigDecimal('1.55') },
            'E1' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('41.0'), 'dest_conc' => BigDecimal('2.05') },
            'F1' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('51.0'), 'dest_conc' => BigDecimal('2.55') },
            'G1' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('61.0'), 'dest_conc' => BigDecimal('3.05') },
            'H1' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('71.0'), 'dest_conc' => BigDecimal('3.55') },
            'A2' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('81.0'), 'dest_conc' => BigDecimal('4.05') },
            'B2' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('91.0'), 'dest_conc' => BigDecimal('4.55') },
            'C2' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('101.0'), 'dest_conc' => BigDecimal('5.05') },
            'D2' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('111.0'), 'dest_conc' => BigDecimal('5.55') },
            'E2' => { 'vol_source_reqd' => BigDecimal('20.0'), 'vol_diluent_reqd' => BigDecimal('0.0'),
                      'amount_in_target' => BigDecimal('121.0'), 'dest_conc' => BigDecimal('6.05') }
          }
        end
        let(:expd_transfers_comp_many_bins) do
          {
            'A1' => { 'dest_locn' => 'A1', 'dest_conc' => BigDecimal('0.05'), 'volume' => BigDecimal('20.0') },
            'B1' => { 'dest_locn' => 'B1', 'dest_conc' => BigDecimal('0.55'), 'volume' => BigDecimal('20.0') },
            'C1' => { 'dest_locn' => 'C1', 'dest_conc' => BigDecimal('1.05'), 'volume' => BigDecimal('20.0') },
            'D1' => { 'dest_locn' => 'D1', 'dest_conc' => BigDecimal('1.55'), 'volume' => BigDecimal('20.0') },
            'E1' => { 'dest_locn' => 'E1', 'dest_conc' => BigDecimal('2.05'), 'volume' => BigDecimal('20.0') },
            'F1' => { 'dest_locn' => 'F1', 'dest_conc' => BigDecimal('2.55'), 'volume' => BigDecimal('20.0') },
            'G1' => { 'dest_locn' => 'G1', 'dest_conc' => BigDecimal('3.05'), 'volume' => BigDecimal('20.0') },
            'H1' => { 'dest_locn' => 'H1', 'dest_conc' => BigDecimal('3.55'), 'volume' => BigDecimal('20.0') },
            'A2' => { 'dest_locn' => 'A2', 'dest_conc' => BigDecimal('4.05'), 'volume' => BigDecimal('20.0') },
            'B2' => { 'dest_locn' => 'B2', 'dest_conc' => BigDecimal('4.55'), 'volume' => BigDecimal('20.0') },
            'C2' => { 'dest_locn' => 'C2', 'dest_conc' => BigDecimal('5.05'), 'volume' => BigDecimal('20.0') },
            'D2' => { 'dest_locn' => 'D2', 'dest_conc' => BigDecimal('5.55'), 'volume' => BigDecimal('20.0') },
            'E2' => { 'dest_locn' => 'E2', 'dest_conc' => BigDecimal('6.05'), 'volume' => BigDecimal('20.0') }
          }
        end

        it 'creates the correct transfers' do
          expect(subject.compute_well_transfers_hash(normalisation_details, num_rows, num_cols))
            .to eq(expd_transfers_comp_many_bins)
        end
      end
    end

    describe '#extract_destination_concentrations' do
      context 'when extracting the destination concentrations' do
        let(:transfer_hash) do
          {
            'A1' => { 'dest_locn' => 'A2', 'dest_conc' => BigDecimal('0.665'), 'volume' => BigDecimal('20.0') },
            'B1' => { 'dest_locn' => 'A1', 'dest_conc' => BigDecimal('0.343'), 'volume' => BigDecimal('20.0') },
            'C1' => { 'dest_locn' => 'A3', 'dest_conc' => BigDecimal('2.135'), 'volume' => BigDecimal('20.0') },
            'D1' => { 'dest_locn' => 'B3', 'dest_conc' => BigDecimal('3.123'), 'volume' => BigDecimal('20.0') },
            'E1' => { 'dest_locn' => 'C3', 'dest_conc' => BigDecimal('3.045'), 'volume' => BigDecimal('20.0') },
            'F1' => { 'dest_locn' => 'B2', 'dest_conc' => BigDecimal('0.743'), 'volume' => BigDecimal('20.0') },
            'G1' => { 'dest_locn' => 'C2', 'dest_conc' => BigDecimal('0.693'), 'volume' => BigDecimal('20.0') }
          }
        end
        let(:expected_dest_concs) do
          {
            'A2' => 0.665,
            'A1' => 0.343,
            'A3' => 2.135,
            'B3' => 3.123,
            'C3' => 3.045,
            'B2' => 0.743,
            'C2' => 0.693
          }
        end

        it 'refactors the transfers hash correctly' do
          expect(subject.extract_destination_concentrations(transfer_hash)).to eq(expected_dest_concs)
        end
      end
    end

    describe '#construct_dest_qc_assay_attributes' do
      let(:transfer_hash) do
        {
          'A1' => { 'dest_locn' => 'A2', 'dest_conc' => BigDecimal('0.665'), 'volume' => BigDecimal('20.0') },
          'B1' => { 'dest_locn' => 'A1', 'dest_conc' => BigDecimal('0.343'), 'volume' => BigDecimal('20.0') },
          'C1' => { 'dest_locn' => 'A3', 'dest_conc' => BigDecimal('2.135'), 'volume' => BigDecimal('20.0') }
        }
      end
      let(:expected_attributes) do
        [
          {
            'uuid' => 'child_uuid',
            'well_location' => 'A2',
            'key' => 'concentration',
            'value' => BigDecimal('0.665'),
            'units' => 'ng/ul',
            'cv' => 0,
            'assay_type' => 'NormalisedBinningCalculator',
            'assay_version' => assay_version
          },
          {
            'uuid' => 'child_uuid',
            'well_location' => 'A1',
            'key' => 'concentration',
            'value' => BigDecimal('0.343'),
            'units' => 'ng/ul',
            'cv' => 0,
            'assay_type' => 'NormalisedBinningCalculator',
            'assay_version' => assay_version
          },
          {
            'uuid' => 'child_uuid',
            'well_location' => 'A3',
            'key' => 'concentration',
            'value' => BigDecimal('2.135'),
            'units' => 'ng/ul',
            'cv' => 0,
            'assay_type' => 'NormalisedBinningCalculator',
            'assay_version' => assay_version
          }
        ]
      end

      it 'creates the expected attibutes' do
        expect(subject.construct_dest_qc_assay_attributes('child_uuid', transfer_hash)).to eq(expected_attributes)
      end
    end

    describe '#compute_presenter_bin_details' do
      context 'when generating presenter well bin details' do
        let(:well_a1) do
          create(:v2_well,
                 position: { 'name' => 'A1' },
                 qc_results: create_list(:qc_result_concentration, 1, value: 0.5))
        end
        let(:well_b1) do
          create(:v2_well,
                 position: { 'name' => 'B1' },
                 qc_results: create_list(:qc_result_concentration, 1, value: 1.0))
        end
        let(:well_c1) do
          create(:v2_well,
                 position: { 'name' => 'C1' },
                 qc_results: create_list(:qc_result_concentration, 1, value: 5.0))
        end
        let(:well_d1) do
          create(:v2_well,
                 position: { 'name' => 'D1' },
                 qc_results: create_list(:qc_result_concentration, 1, value: 5.5))
        end
        let(:child_plate) do
          create :v2_plate,
                 uuid: parent_uuid,
                 barcode_number: '3',
                 size: plate_size,
                 wells: [well_a1, well_b1, well_c1, well_d1],
                 outer_requests: requests
        end

        let(:expected_bin_details) do
          {
            'A1' => { 'colour' => 1, 'pcr_cycles' => 16 },
            'B1' => { 'colour' => 1, 'pcr_cycles' => 16 },
            'C1' => { 'colour' => 2, 'pcr_cycles' => 14 },
            'D1' => { 'colour' => 2, 'pcr_cycles' => 14 }
          }
        end

        it 'creates the correct hash' do
          expect(subject.compute_presenter_bin_details(child_plate)).to eq(expected_bin_details)
        end
      end
    end
  end
end
