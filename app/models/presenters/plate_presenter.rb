# frozen_string_literal: true

require_dependency 'presenters/presenter'

# Basic core presenter class for plates
class Presenters::PlatePresenter
  include Presenters::Presenter
  include PlateWalking
  include Presenters::RobotControlled
  include Presenters::ExtendedCsv

  class_attribute :aliquot_partial, :summary_partial, :well_failure_states, :style_class

  self.summary_partial = 'labware/plates/standard_summary'
  self.aliquot_partial = 'standard_aliquot'
  # summary_items is a hash of a label label, and a symbol representing the
  # method to call to get the value
  self.summary_items = {
    'Barcode' => :barcode,
    'Number of wells' => :number_of_wells,
    'Plate type' => :purpose_name,
    'Current plate state' => :state,
    'Input plate barcode' => :input_barcode,
    'PCR Cycles' => :pcr_cycles,
    'Created on' => :created_on
  }
  self.well_failure_states = [:passed]
  self.style_class = 'standard'

  # Note: Validation here is intended as a warning. Rather than strict validation
  validates :pcr_cycles_specified,
            numericality: { less_than_or_equal_to: 1, message: 'is not consistent across the plate.' },
            unless: :multiple_requests_per_well?

  validates :pcr_cycles,
            inclusion: { in: ->(r) { r.expected_cycles },
                         message: 'differs from standard. %{value} cycles have been requested.' },
            if: :expected_cycles

  validates_with Validators::InProgressValidator

  delegate :tagged?, :number_of_columns, :number_of_rows, :size, :purpose, :human_barcode, :priority, :pools, to: :labware
  delegate :pool_index, to: :pools

  alias plate_to_walk labware
  # Purpose returns the plate or tube purpose of the labware.
  # Currently this needs to be specialised for tube or plate but in future
  # both should use #purpose and we'll be able to share the same method for
  # all presenters.
  alias plate_purpose purpose

  def number_of_wells
    "#{number_of_filled_wells}/#{size}"
  end

  def pcr_cycles
    pcr_cycles_specified.zero? ? 'No pools specified' : cycles.to_sentence
  end

  def expected_cycles
    purpose_config.dig(:warnings, :pcr_cycles_not_in)
  end

  def label
    label_class = purpose_config.fetch(:label_class)
    label_class.constantize.new(labware)
  end

  def tube_labels
    # Optimization: To avoid needing to load in the tube aliquots, we use the transfers into the
    # tube to work out the pool size. This information is already available. Two values are different
    # for ISC though. TODO: MUST RE-JIG
    tubes_and_sources.map { |tube| Labels::TubeLabel.new(tube, pool_size: tube.pool_size) }
  end

  def control_tube_display
    yield if labware.transfers_to_tubes?
  end

  def labware_form_details(view)
    { url: view.limber_plate_path(labware), as: :plate }
  end

  def tubes_and_sources
    @tubes_and_sources ||= Presenters::TubesWithSources.build(wells: wells, pools: pools)
  end

  def csv_file_links
    links = [
      ['Download Concentration CSV', [:limber_plate, :export, { id: 'concentrations', limber_plate_id: human_barcode, format: :csv }]]
    ]
    links << ['Download Worksheet CSV', { format: :csv }] if csv.present?
    links
  end

  def filename(offset = nil)
    "#{labware.barcode.prefix}#{labware.barcode.number}#{offset}.csv".tr(' ', '_')
  end

  def tag_sequences
    @tag_sequences ||= wells.each_with_object([]) do |well, tags|
      well.aliquots.each do |aliquot|
        tags << [aliquot.tag_oligo, aliquot.tag2_oligo]
      end
    end
  end

  def wells
    labware.wells_in_columns
  end

  private

  def multiple_requests_per_well?
    wells.any?(&:multiple_requests?)
  end

  def number_of_filled_wells
    wells.count { |w| w.aliquots.present? }
  end

  def pcr_cycles_specified
    cycles.length
  end

  def cycles
    labware.pcr_cycles
  end

  def active_request_types
    wells.reduce([]) do |active_requests, well|
      active_requests.concat(
        well.active_requests.map do |request|
          request.request_type.key
        end
      )
    end
  end
end
