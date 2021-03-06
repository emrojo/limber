# frozen_string_literal: true

FactoryBot.define do
  factory :qc_result, class: Sequencescape::Api::V2::QcResult do
    key { 'molarity' }
    value { '1.5' }
    units { 'nM' }
    created_at { Time.current }

    skip_create

    factory :qc_result_concentration do
      key { 'concentration' }
      units { 'ng/ul' }
    end
  end
end
