# frozen_string_literal: true
# This file is part of Illumina-B Pipeline is distributed under the terms of GNU General Public License version 3 or later;
# Please refer to the LICENSE and README files for information on licensing and authorship of this file.
# Copyright (C) 2015 Genome Research Ltd.
module Presenters
  ##
  # Presents a dead-end plate with no children
  class EndPlatePresenter < StandardPresenter
    self.authenticated_tab_states = {
      pending: ['labware-summary-button', 'labware-state-button'],
      started: ['labware-state-button',   'labware-summary-button'],
      passed: ['labware-summary-button']
    }
  end
end