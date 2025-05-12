import { initAll } from 'govuk-frontend'
import { Application } from '@hotwired/stimulus'

window.Stimulus = Application.start()

initAll()
