// Import the component being tested
import { mount } from '@vue/test-utils'
import flushPromises from 'flush-promises'
import PlateScan from 'shared/components/PlateScan.vue'
import { jsonCollectionFactory, attributesFactory, devourFactory } from 'test_support/factories'
import mockApi from 'test_support/mock_api'

// create an extended `Vue` constructor

import localVue from 'test_support/base_vue'

describe('PlateScan', () => {
  const plateUuid = 'afabla7e-9498-42d6-964e-50f61ded6d9a'
  const nullPlate = { data: [] }
  const goodPlate = jsonCollectionFactory('plate', [{ uuid: plateUuid }])
  const badPlate = jsonCollectionFactory('plate', [{ uuid: plateUuid , number_of_columns: 24, number_of_rows: 8 }])

  const wrapperFactory = function(api = mockApi()) {
    // Not ideal using mount here, but having massive trouble
    // triggering change events on unmounted components
    return mount(PlateScan, {
      propsData: {
        label: 'My Plate',
        description: 'Scan it in',
        api: api.devour,
        plateCols: 12,
        plateRows: 8,
        includes: {wells: ['requests_as_source',{ aliquots: 'request' }]}
      },
      localVue
    })
  }

  it('renders the provided label', () => {
    const wrapper = wrapperFactory()

    expect(wrapper.find('label').text()).toEqual('My Plate')
  })

  it('renders the provided description', () => {
    const wrapper = wrapperFactory()

    expect(wrapper.find('.text-muted').text()).toEqual('Scan it in')
  })

  it('is invalid if it can not find a plate', async () => {
    const api = mockApi()
    api.mockGet('plates', {
      filter: { barcode: 'not a barcode' },
      include: { wells: ['requests_as_source', { aliquots: 'request' }] },
      fields: { plates: 'labware_barcode,uuid,number_of_rows,number_of_columns' }
    }, nullPlate)
    const wrapper = wrapperFactory(api)

    wrapper.find('input').setValue('not a barcode')
    wrapper.find('input').trigger('change')

    expect(wrapper.find('.wait-plate').exists()).toBe(true)

    await flushPromises()

    expect(wrapper.find('.invalid-feedback').text()).toEqual('Could not find plate')
    expect(wrapper.emitted()).toEqual({
      change: [
        [{ state: 'searching', plate: null }],
        [{ state: 'invalid', plate: null }]
      ]
    })
  })

  it('is invalid if there are api troubles', async () => {
    const api = mockApi()
    api.mockGet('plates', {
      filter: { barcode: 'Good barcode' },
      include: { wells: ['requests_as_source', { aliquots: 'request' }] },
      fields: { plates: 'labware_barcode,uuid,number_of_rows,number_of_columns' }
    }, { 'errors': [{
      title: 'Not good',
      detail: 'Very not good',
      code: 500,
      status: 500
    }]}, 500)
    const wrapper = wrapperFactory(api)

    wrapper.find('input').setValue('Good barcode')
    wrapper.find('input').trigger('change')

    expect(wrapper.find('.wait-plate').exists()).toBe(true)

    await flushPromises()

    expect(wrapper.find('.invalid-feedback').text()).toEqual('Nope')
    expect(wrapper.emitted()).toEqual({
      change: [
        [{ state: 'searching', plate: null }],
        [{ state: 'invalid', plate: null }]
      ]
    })
  })

  it('is valid if it can find a plate', async () => {
    const api = mockApi()
    const wrapper = wrapperFactory(api)

    api.mockGet('plates',{
      include: { wells: ['requests_as_source', { aliquots: 'request' }] },
      filter: { barcode: 'DN12345' },
      fields: { plates: 'labware_barcode,uuid,number_of_rows,number_of_columns' }
    }, goodPlate)

    wrapper.find('input').setValue('DN12345')
    wrapper.find('input').trigger('change')

    expect(wrapper.find('.wait-plate').exists()).toBe(true)

    await flushPromises()

    expect(wrapper.find('.valid-feedback').text()).toEqual('Great!')

    const events = wrapper.emitted()

    expect(events.change.length).toEqual(2)
    expect(events.change[0]).toEqual([{ state: 'searching', plate: null }])
    expect(events.change[1][0].state).toEqual('valid')
    expect(events.change[1][0].plate.uuid).toEqual(plateUuid)
  })

  it('is invalid if the plate is the wrong size', async () => {
    const api = mockApi()
    const wrapper = wrapperFactory(api)

    api.mockGet('plates',{
      include: { wells: ['requests_as_source',{aliquots: 'request'}] },
      filter: { barcode: 'Good barcode' },
      fields: { plates: 'labware_barcode,uuid,number_of_rows,number_of_columns' }
    }, badPlate)

    wrapper.find('input').setValue('Good barcode')
    wrapper.find('input').trigger('change')

    expect(wrapper.find('.wait-plate').exists()).toBe(true)

    await flushPromises()

    expect(wrapper.find('.invalid-feedback').text()).toEqual('The plate should be 12×8 wells in size')
    const events = wrapper.emitted()

    expect(events.change.length).toEqual(2)
    expect(events.change[0]).toEqual([{ state: 'searching', plate: null }])
    expect(events.change[1][0].state).toEqual('invalid')
    expect(events.change[1][0].plate.uuid).toEqual(plateUuid)
  })

})
