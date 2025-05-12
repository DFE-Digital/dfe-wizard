(() => {
  // node_modules/govuk-frontend/dist/govuk/common/index.mjs
  function getFragmentFromUrl(url) {
    if (!url.includes("#")) {
      return void 0;
    }
    return url.split("#").pop();
  }
  function getBreakpoint(name) {
    const property = `--govuk-frontend-breakpoint-${name}`;
    const value = window.getComputedStyle(document.documentElement).getPropertyValue(property);
    return {
      property,
      value: value || void 0
    };
  }
  function setFocus($element, options = {}) {
    var _options$onBeforeFocu;
    const isFocusable = $element.getAttribute("tabindex");
    if (!isFocusable) {
      $element.setAttribute("tabindex", "-1");
    }
    function onFocus() {
      $element.addEventListener("blur", onBlur, {
        once: true
      });
    }
    function onBlur() {
      var _options$onBlur;
      (_options$onBlur = options.onBlur) == null || _options$onBlur.call($element);
      if (!isFocusable) {
        $element.removeAttribute("tabindex");
      }
    }
    $element.addEventListener("focus", onFocus, {
      once: true
    });
    (_options$onBeforeFocu = options.onBeforeFocus) == null || _options$onBeforeFocu.call($element);
    $element.focus();
  }
  function isInitialised($root, moduleName) {
    return $root instanceof HTMLElement && $root.hasAttribute(`data-${moduleName}-init`);
  }
  function isSupported($scope = document.body) {
    if (!$scope) {
      return false;
    }
    return $scope.classList.contains("govuk-frontend-supported");
  }
  function isArray(option) {
    return Array.isArray(option);
  }
  function isObject(option) {
    return !!option && typeof option === "object" && !isArray(option);
  }
  function formatErrorMessage(Component2, message) {
    return `${Component2.moduleName}: ${message}`;
  }

  // node_modules/govuk-frontend/dist/govuk/errors/index.mjs
  var GOVUKFrontendError = class extends Error {
    constructor(...args) {
      super(...args);
      this.name = "GOVUKFrontendError";
    }
  };
  var SupportError = class extends GOVUKFrontendError {
    /**
     * Checks if GOV.UK Frontend is supported on this page
     *
     * @param {HTMLElement | null} [$scope] - HTML element `<body>` checked for browser support
     */
    constructor($scope = document.body) {
      const supportMessage = "noModule" in HTMLScriptElement.prototype ? 'GOV.UK Frontend initialised without `<body class="govuk-frontend-supported">` from template `<script>` snippet' : "GOV.UK Frontend is not supported in this browser";
      super($scope ? supportMessage : 'GOV.UK Frontend initialised without `<script type="module">`');
      this.name = "SupportError";
    }
  };
  var ConfigError = class extends GOVUKFrontendError {
    constructor(...args) {
      super(...args);
      this.name = "ConfigError";
    }
  };
  var ElementError = class extends GOVUKFrontendError {
    constructor(messageOrOptions) {
      let message = typeof messageOrOptions === "string" ? messageOrOptions : "";
      if (typeof messageOrOptions === "object") {
        const {
          component,
          identifier,
          element,
          expectedType
        } = messageOrOptions;
        message = identifier;
        message += element ? ` is not of type ${expectedType != null ? expectedType : "HTMLElement"}` : " not found";
        message = formatErrorMessage(component, message);
      }
      super(message);
      this.name = "ElementError";
    }
  };
  var InitError = class extends GOVUKFrontendError {
    constructor(componentOrMessage) {
      const message = typeof componentOrMessage === "string" ? componentOrMessage : formatErrorMessage(componentOrMessage, `Root element (\`$root\`) already initialised`);
      super(message);
      this.name = "InitError";
    }
  };

  // node_modules/govuk-frontend/dist/govuk/component.mjs
  var Component = class {
    /**
     * Returns the root element of the component
     *
     * @protected
     * @returns {RootElementType} - the root element of component
     */
    get $root() {
      return this._$root;
    }
    constructor($root) {
      this._$root = void 0;
      const childConstructor = this.constructor;
      if (typeof childConstructor.moduleName !== "string") {
        throw new InitError(`\`moduleName\` not defined in component`);
      }
      if (!($root instanceof childConstructor.elementType)) {
        throw new ElementError({
          element: $root,
          component: childConstructor,
          identifier: "Root element (`$root`)",
          expectedType: childConstructor.elementType.name
        });
      } else {
        this._$root = $root;
      }
      childConstructor.checkSupport();
      this.checkInitialised();
      const moduleName = childConstructor.moduleName;
      this.$root.setAttribute(`data-${moduleName}-init`, "");
    }
    checkInitialised() {
      const constructor = this.constructor;
      const moduleName = constructor.moduleName;
      if (moduleName && isInitialised(this.$root, moduleName)) {
        throw new InitError(constructor);
      }
    }
    static checkSupport() {
      if (!isSupported()) {
        throw new SupportError();
      }
    }
  };
  Component.elementType = HTMLElement;

  // node_modules/govuk-frontend/dist/govuk/common/configuration.mjs
  var configOverride = Symbol.for("configOverride");
  var ConfigurableComponent = class extends Component {
    [configOverride](param) {
      return {};
    }
    /**
     * Returns the root element of the component
     *
     * @protected
     * @returns {ConfigurationType} - the root element of component
     */
    get config() {
      return this._config;
    }
    constructor($root, config) {
      super($root);
      this._config = void 0;
      const childConstructor = this.constructor;
      if (!isObject(childConstructor.defaults)) {
        throw new ConfigError(formatErrorMessage(childConstructor, "Config passed as parameter into constructor but no defaults defined"));
      }
      const datasetConfig = normaliseDataset(childConstructor, this._$root.dataset);
      this._config = mergeConfigs(childConstructor.defaults, config != null ? config : {}, this[configOverride](datasetConfig), datasetConfig);
    }
  };
  function normaliseString(value, property) {
    const trimmedValue = value ? value.trim() : "";
    let output;
    let outputType = property == null ? void 0 : property.type;
    if (!outputType) {
      if (["true", "false"].includes(trimmedValue)) {
        outputType = "boolean";
      }
      if (trimmedValue.length > 0 && isFinite(Number(trimmedValue))) {
        outputType = "number";
      }
    }
    switch (outputType) {
      case "boolean":
        output = trimmedValue === "true";
        break;
      case "number":
        output = Number(trimmedValue);
        break;
      default:
        output = value;
    }
    return output;
  }
  function normaliseDataset(Component2, dataset) {
    if (!isObject(Component2.schema)) {
      throw new ConfigError(formatErrorMessage(Component2, "Config passed as parameter into constructor but no schema defined"));
    }
    const out = {};
    const entries = Object.entries(Component2.schema.properties);
    for (const entry of entries) {
      const [namespace, property] = entry;
      const field = namespace.toString();
      if (field in dataset) {
        out[field] = normaliseString(dataset[field], property);
      }
      if ((property == null ? void 0 : property.type) === "object") {
        out[field] = extractConfigByNamespace(Component2.schema, dataset, namespace);
      }
    }
    return out;
  }
  function mergeConfigs(...configObjects) {
    const formattedConfigObject = {};
    for (const configObject of configObjects) {
      for (const key of Object.keys(configObject)) {
        const option = formattedConfigObject[key];
        const override = configObject[key];
        if (isObject(option) && isObject(override)) {
          formattedConfigObject[key] = mergeConfigs(option, override);
        } else {
          formattedConfigObject[key] = override;
        }
      }
    }
    return formattedConfigObject;
  }
  function validateConfig(schema, config) {
    const validationErrors = [];
    for (const [name, conditions] of Object.entries(schema)) {
      const errors = [];
      if (Array.isArray(conditions)) {
        for (const {
          required,
          errorMessage
        } of conditions) {
          if (!required.every((key) => !!config[key])) {
            errors.push(errorMessage);
          }
        }
        if (name === "anyOf" && !(conditions.length - errors.length >= 1)) {
          validationErrors.push(...errors);
        }
      }
    }
    return validationErrors;
  }
  function extractConfigByNamespace(schema, dataset, namespace) {
    const property = schema.properties[namespace];
    if ((property == null ? void 0 : property.type) !== "object") {
      return;
    }
    const newObject = {
      [namespace]: {}
    };
    for (const [key, value] of Object.entries(dataset)) {
      let current = newObject;
      const keyParts = key.split(".");
      for (const [index, name] of keyParts.entries()) {
        if (isObject(current)) {
          if (index < keyParts.length - 1) {
            if (!isObject(current[name])) {
              current[name] = {};
            }
            current = current[name];
          } else if (key !== namespace) {
            current[name] = normaliseString(value);
          }
        }
      }
    }
    return newObject[namespace];
  }

  // node_modules/govuk-frontend/dist/govuk/i18n.mjs
  var I18n = class _I18n {
    constructor(translations = {}, config = {}) {
      var _config$locale;
      this.translations = void 0;
      this.locale = void 0;
      this.translations = translations;
      this.locale = (_config$locale = config.locale) != null ? _config$locale : document.documentElement.lang || "en";
    }
    t(lookupKey, options) {
      if (!lookupKey) {
        throw new Error("i18n: lookup key missing");
      }
      let translation = this.translations[lookupKey];
      if (typeof (options == null ? void 0 : options.count) === "number" && typeof translation === "object") {
        const translationPluralForm = translation[this.getPluralSuffix(lookupKey, options.count)];
        if (translationPluralForm) {
          translation = translationPluralForm;
        }
      }
      if (typeof translation === "string") {
        if (translation.match(/%{(.\S+)}/)) {
          if (!options) {
            throw new Error("i18n: cannot replace placeholders in string if no option data provided");
          }
          return this.replacePlaceholders(translation, options);
        }
        return translation;
      }
      return lookupKey;
    }
    replacePlaceholders(translationString, options) {
      const formatter = Intl.NumberFormat.supportedLocalesOf(this.locale).length ? new Intl.NumberFormat(this.locale) : void 0;
      return translationString.replace(/%{(.\S+)}/g, function(placeholderWithBraces, placeholderKey) {
        if (Object.prototype.hasOwnProperty.call(options, placeholderKey)) {
          const placeholderValue = options[placeholderKey];
          if (placeholderValue === false || typeof placeholderValue !== "number" && typeof placeholderValue !== "string") {
            return "";
          }
          if (typeof placeholderValue === "number") {
            return formatter ? formatter.format(placeholderValue) : `${placeholderValue}`;
          }
          return placeholderValue;
        }
        throw new Error(`i18n: no data found to replace ${placeholderWithBraces} placeholder in string`);
      });
    }
    hasIntlPluralRulesSupport() {
      return Boolean("PluralRules" in window.Intl && Intl.PluralRules.supportedLocalesOf(this.locale).length);
    }
    getPluralSuffix(lookupKey, count) {
      count = Number(count);
      if (!isFinite(count)) {
        return "other";
      }
      const translation = this.translations[lookupKey];
      const preferredForm = this.hasIntlPluralRulesSupport() ? new Intl.PluralRules(this.locale).select(count) : this.selectPluralFormUsingFallbackRules(count);
      if (typeof translation === "object") {
        if (preferredForm in translation) {
          return preferredForm;
        } else if ("other" in translation) {
          console.warn(`i18n: Missing plural form ".${preferredForm}" for "${this.locale}" locale. Falling back to ".other".`);
          return "other";
        }
      }
      throw new Error(`i18n: Plural form ".other" is required for "${this.locale}" locale`);
    }
    selectPluralFormUsingFallbackRules(count) {
      count = Math.abs(Math.floor(count));
      const ruleset = this.getPluralRulesForLocale();
      if (ruleset) {
        return _I18n.pluralRules[ruleset](count);
      }
      return "other";
    }
    getPluralRulesForLocale() {
      const localeShort = this.locale.split("-")[0];
      for (const pluralRule in _I18n.pluralRulesMap) {
        const languages = _I18n.pluralRulesMap[pluralRule];
        if (languages.includes(this.locale) || languages.includes(localeShort)) {
          return pluralRule;
        }
      }
    }
  };
  I18n.pluralRulesMap = {
    arabic: ["ar"],
    chinese: ["my", "zh", "id", "ja", "jv", "ko", "ms", "th", "vi"],
    french: ["hy", "bn", "fr", "gu", "hi", "fa", "pa", "zu"],
    german: ["af", "sq", "az", "eu", "bg", "ca", "da", "nl", "en", "et", "fi", "ka", "de", "el", "hu", "lb", "no", "so", "sw", "sv", "ta", "te", "tr", "ur"],
    irish: ["ga"],
    russian: ["ru", "uk"],
    scottish: ["gd"],
    spanish: ["pt-PT", "it", "es"],
    welsh: ["cy"]
  };
  I18n.pluralRules = {
    arabic(n) {
      if (n === 0) {
        return "zero";
      }
      if (n === 1) {
        return "one";
      }
      if (n === 2) {
        return "two";
      }
      if (n % 100 >= 3 && n % 100 <= 10) {
        return "few";
      }
      if (n % 100 >= 11 && n % 100 <= 99) {
        return "many";
      }
      return "other";
    },
    chinese() {
      return "other";
    },
    french(n) {
      return n === 0 || n === 1 ? "one" : "other";
    },
    german(n) {
      return n === 1 ? "one" : "other";
    },
    irish(n) {
      if (n === 1) {
        return "one";
      }
      if (n === 2) {
        return "two";
      }
      if (n >= 3 && n <= 6) {
        return "few";
      }
      if (n >= 7 && n <= 10) {
        return "many";
      }
      return "other";
    },
    russian(n) {
      const lastTwo = n % 100;
      const last = lastTwo % 10;
      if (last === 1 && lastTwo !== 11) {
        return "one";
      }
      if (last >= 2 && last <= 4 && !(lastTwo >= 12 && lastTwo <= 14)) {
        return "few";
      }
      if (last === 0 || last >= 5 && last <= 9 || lastTwo >= 11 && lastTwo <= 14) {
        return "many";
      }
      return "other";
    },
    scottish(n) {
      if (n === 1 || n === 11) {
        return "one";
      }
      if (n === 2 || n === 12) {
        return "two";
      }
      if (n >= 3 && n <= 10 || n >= 13 && n <= 19) {
        return "few";
      }
      return "other";
    },
    spanish(n) {
      if (n === 1) {
        return "one";
      }
      if (n % 1e6 === 0 && n !== 0) {
        return "many";
      }
      return "other";
    },
    welsh(n) {
      if (n === 0) {
        return "zero";
      }
      if (n === 1) {
        return "one";
      }
      if (n === 2) {
        return "two";
      }
      if (n === 3) {
        return "few";
      }
      if (n === 6) {
        return "many";
      }
      return "other";
    }
  };

  // node_modules/govuk-frontend/dist/govuk/components/accordion/accordion.mjs
  var Accordion = class _Accordion extends ConfigurableComponent {
    /**
     * @param {Element | null} $root - HTML element to use for accordion
     * @param {AccordionConfig} [config] - Accordion config
     */
    constructor($root, config = {}) {
      super($root, config);
      this.i18n = void 0;
      this.controlsClass = "govuk-accordion__controls";
      this.showAllClass = "govuk-accordion__show-all";
      this.showAllTextClass = "govuk-accordion__show-all-text";
      this.sectionClass = "govuk-accordion__section";
      this.sectionExpandedClass = "govuk-accordion__section--expanded";
      this.sectionButtonClass = "govuk-accordion__section-button";
      this.sectionHeaderClass = "govuk-accordion__section-header";
      this.sectionHeadingClass = "govuk-accordion__section-heading";
      this.sectionHeadingDividerClass = "govuk-accordion__section-heading-divider";
      this.sectionHeadingTextClass = "govuk-accordion__section-heading-text";
      this.sectionHeadingTextFocusClass = "govuk-accordion__section-heading-text-focus";
      this.sectionShowHideToggleClass = "govuk-accordion__section-toggle";
      this.sectionShowHideToggleFocusClass = "govuk-accordion__section-toggle-focus";
      this.sectionShowHideTextClass = "govuk-accordion__section-toggle-text";
      this.upChevronIconClass = "govuk-accordion-nav__chevron";
      this.downChevronIconClass = "govuk-accordion-nav__chevron--down";
      this.sectionSummaryClass = "govuk-accordion__section-summary";
      this.sectionSummaryFocusClass = "govuk-accordion__section-summary-focus";
      this.sectionContentClass = "govuk-accordion__section-content";
      this.$sections = void 0;
      this.$showAllButton = null;
      this.$showAllIcon = null;
      this.$showAllText = null;
      this.i18n = new I18n(this.config.i18n);
      const $sections = this.$root.querySelectorAll(`.${this.sectionClass}`);
      if (!$sections.length) {
        throw new ElementError({
          component: _Accordion,
          identifier: `Sections (\`<div class="${this.sectionClass}">\`)`
        });
      }
      this.$sections = $sections;
      this.initControls();
      this.initSectionHeaders();
      this.updateShowAllButton(this.areAllSectionsOpen());
    }
    initControls() {
      this.$showAllButton = document.createElement("button");
      this.$showAllButton.setAttribute("type", "button");
      this.$showAllButton.setAttribute("class", this.showAllClass);
      this.$showAllButton.setAttribute("aria-expanded", "false");
      this.$showAllIcon = document.createElement("span");
      this.$showAllIcon.classList.add(this.upChevronIconClass);
      this.$showAllButton.appendChild(this.$showAllIcon);
      const $accordionControls = document.createElement("div");
      $accordionControls.setAttribute("class", this.controlsClass);
      $accordionControls.appendChild(this.$showAllButton);
      this.$root.insertBefore($accordionControls, this.$root.firstChild);
      this.$showAllText = document.createElement("span");
      this.$showAllText.classList.add(this.showAllTextClass);
      this.$showAllButton.appendChild(this.$showAllText);
      this.$showAllButton.addEventListener("click", () => this.onShowOrHideAllToggle());
      if ("onbeforematch" in document) {
        document.addEventListener("beforematch", (event) => this.onBeforeMatch(event));
      }
    }
    initSectionHeaders() {
      this.$sections.forEach(($section, i) => {
        const $header = $section.querySelector(`.${this.sectionHeaderClass}`);
        if (!$header) {
          throw new ElementError({
            component: _Accordion,
            identifier: `Section headers (\`<div class="${this.sectionHeaderClass}">\`)`
          });
        }
        this.constructHeaderMarkup($header, i);
        this.setExpanded(this.isExpanded($section), $section);
        $header.addEventListener("click", () => this.onSectionToggle($section));
        this.setInitialState($section);
      });
    }
    constructHeaderMarkup($header, index) {
      const $span = $header.querySelector(`.${this.sectionButtonClass}`);
      const $heading = $header.querySelector(`.${this.sectionHeadingClass}`);
      const $summary = $header.querySelector(`.${this.sectionSummaryClass}`);
      if (!$heading) {
        throw new ElementError({
          component: _Accordion,
          identifier: `Section heading (\`.${this.sectionHeadingClass}\`)`
        });
      }
      if (!$span) {
        throw new ElementError({
          component: _Accordion,
          identifier: `Section button placeholder (\`<span class="${this.sectionButtonClass}">\`)`
        });
      }
      const $button = document.createElement("button");
      $button.setAttribute("type", "button");
      $button.setAttribute("aria-controls", `${this.$root.id}-content-${index + 1}`);
      for (const attr of Array.from($span.attributes)) {
        if (attr.name !== "id") {
          $button.setAttribute(attr.name, attr.value);
        }
      }
      const $headingText = document.createElement("span");
      $headingText.classList.add(this.sectionHeadingTextClass);
      $headingText.id = $span.id;
      const $headingTextFocus = document.createElement("span");
      $headingTextFocus.classList.add(this.sectionHeadingTextFocusClass);
      $headingText.appendChild($headingTextFocus);
      Array.from($span.childNodes).forEach(($child) => $headingTextFocus.appendChild($child));
      const $showHideToggle = document.createElement("span");
      $showHideToggle.classList.add(this.sectionShowHideToggleClass);
      $showHideToggle.setAttribute("data-nosnippet", "");
      const $showHideToggleFocus = document.createElement("span");
      $showHideToggleFocus.classList.add(this.sectionShowHideToggleFocusClass);
      $showHideToggle.appendChild($showHideToggleFocus);
      const $showHideText = document.createElement("span");
      const $showHideIcon = document.createElement("span");
      $showHideIcon.classList.add(this.upChevronIconClass);
      $showHideToggleFocus.appendChild($showHideIcon);
      $showHideText.classList.add(this.sectionShowHideTextClass);
      $showHideToggleFocus.appendChild($showHideText);
      $button.appendChild($headingText);
      $button.appendChild(this.getButtonPunctuationEl());
      if ($summary) {
        const $summarySpan = document.createElement("span");
        const $summarySpanFocus = document.createElement("span");
        $summarySpanFocus.classList.add(this.sectionSummaryFocusClass);
        $summarySpan.appendChild($summarySpanFocus);
        for (const attr of Array.from($summary.attributes)) {
          $summarySpan.setAttribute(attr.name, attr.value);
        }
        Array.from($summary.childNodes).forEach(($child) => $summarySpanFocus.appendChild($child));
        $summary.remove();
        $button.appendChild($summarySpan);
        $button.appendChild(this.getButtonPunctuationEl());
      }
      $button.appendChild($showHideToggle);
      $heading.removeChild($span);
      $heading.appendChild($button);
    }
    onBeforeMatch(event) {
      const $fragment = event.target;
      if (!($fragment instanceof Element)) {
        return;
      }
      const $section = $fragment.closest(`.${this.sectionClass}`);
      if ($section) {
        this.setExpanded(true, $section);
      }
    }
    onSectionToggle($section) {
      const nowExpanded = !this.isExpanded($section);
      this.setExpanded(nowExpanded, $section);
      this.storeState($section, nowExpanded);
    }
    onShowOrHideAllToggle() {
      const nowExpanded = !this.areAllSectionsOpen();
      this.$sections.forEach(($section) => {
        this.setExpanded(nowExpanded, $section);
        this.storeState($section, nowExpanded);
      });
      this.updateShowAllButton(nowExpanded);
    }
    setExpanded(expanded, $section) {
      const $showHideIcon = $section.querySelector(`.${this.upChevronIconClass}`);
      const $showHideText = $section.querySelector(`.${this.sectionShowHideTextClass}`);
      const $button = $section.querySelector(`.${this.sectionButtonClass}`);
      const $content = $section.querySelector(`.${this.sectionContentClass}`);
      if (!$content) {
        throw new ElementError({
          component: _Accordion,
          identifier: `Section content (\`<div class="${this.sectionContentClass}">\`)`
        });
      }
      if (!$showHideIcon || !$showHideText || !$button) {
        return;
      }
      const newButtonText = expanded ? this.i18n.t("hideSection") : this.i18n.t("showSection");
      $showHideText.textContent = newButtonText;
      $button.setAttribute("aria-expanded", `${expanded}`);
      const ariaLabelParts = [];
      const $headingText = $section.querySelector(`.${this.sectionHeadingTextClass}`);
      if ($headingText) {
        ariaLabelParts.push(`${$headingText.textContent}`.trim());
      }
      const $summary = $section.querySelector(`.${this.sectionSummaryClass}`);
      if ($summary) {
        ariaLabelParts.push(`${$summary.textContent}`.trim());
      }
      const ariaLabelMessage = expanded ? this.i18n.t("hideSectionAriaLabel") : this.i18n.t("showSectionAriaLabel");
      ariaLabelParts.push(ariaLabelMessage);
      $button.setAttribute("aria-label", ariaLabelParts.join(" , "));
      if (expanded) {
        $content.removeAttribute("hidden");
        $section.classList.add(this.sectionExpandedClass);
        $showHideIcon.classList.remove(this.downChevronIconClass);
      } else {
        $content.setAttribute("hidden", "until-found");
        $section.classList.remove(this.sectionExpandedClass);
        $showHideIcon.classList.add(this.downChevronIconClass);
      }
      this.updateShowAllButton(this.areAllSectionsOpen());
    }
    isExpanded($section) {
      return $section.classList.contains(this.sectionExpandedClass);
    }
    areAllSectionsOpen() {
      return Array.from(this.$sections).every(($section) => this.isExpanded($section));
    }
    updateShowAllButton(expanded) {
      if (!this.$showAllButton || !this.$showAllText || !this.$showAllIcon) {
        return;
      }
      this.$showAllButton.setAttribute("aria-expanded", expanded.toString());
      this.$showAllText.textContent = expanded ? this.i18n.t("hideAllSections") : this.i18n.t("showAllSections");
      this.$showAllIcon.classList.toggle(this.downChevronIconClass, !expanded);
    }
    /**
     * Get the identifier for a section
     *
     * We need a unique way of identifying each content in the Accordion.
     * Since an `#id` should be unique and an `id` is required for `aria-`
     * attributes `id` can be safely used.
     *
     * @param {Element} $section - Section element
     * @returns {string | undefined | null} Identifier for section
     */
    getIdentifier($section) {
      const $button = $section.querySelector(`.${this.sectionButtonClass}`);
      return $button == null ? void 0 : $button.getAttribute("aria-controls");
    }
    storeState($section, isExpanded) {
      if (!this.config.rememberExpanded) {
        return;
      }
      const id = this.getIdentifier($section);
      if (id) {
        try {
          window.sessionStorage.setItem(id, isExpanded.toString());
        } catch (exception) {
        }
      }
    }
    setInitialState($section) {
      if (!this.config.rememberExpanded) {
        return;
      }
      const id = this.getIdentifier($section);
      if (id) {
        try {
          const state = window.sessionStorage.getItem(id);
          if (state !== null) {
            this.setExpanded(state === "true", $section);
          }
        } catch (exception) {
        }
      }
    }
    getButtonPunctuationEl() {
      const $punctuationEl = document.createElement("span");
      $punctuationEl.classList.add("govuk-visually-hidden", this.sectionHeadingDividerClass);
      $punctuationEl.textContent = ", ";
      return $punctuationEl;
    }
  };
  Accordion.moduleName = "govuk-accordion";
  Accordion.defaults = Object.freeze({
    i18n: {
      hideAllSections: "Hide all sections",
      hideSection: "Hide",
      hideSectionAriaLabel: "Hide this section",
      showAllSections: "Show all sections",
      showSection: "Show",
      showSectionAriaLabel: "Show this section"
    },
    rememberExpanded: true
  });
  Accordion.schema = Object.freeze({
    properties: {
      i18n: {
        type: "object"
      },
      rememberExpanded: {
        type: "boolean"
      }
    }
  });

  // node_modules/govuk-frontend/dist/govuk/components/button/button.mjs
  var DEBOUNCE_TIMEOUT_IN_SECONDS = 1;
  var Button = class extends ConfigurableComponent {
    /**
     * @param {Element | null} $root - HTML element to use for button
     * @param {ButtonConfig} [config] - Button config
     */
    constructor($root, config = {}) {
      super($root, config);
      this.debounceFormSubmitTimer = null;
      this.$root.addEventListener("keydown", (event) => this.handleKeyDown(event));
      this.$root.addEventListener("click", (event) => this.debounce(event));
    }
    handleKeyDown(event) {
      const $target = event.target;
      if (event.key !== " ") {
        return;
      }
      if ($target instanceof HTMLElement && $target.getAttribute("role") === "button") {
        event.preventDefault();
        $target.click();
      }
    }
    debounce(event) {
      if (!this.config.preventDoubleClick) {
        return;
      }
      if (this.debounceFormSubmitTimer) {
        event.preventDefault();
        return false;
      }
      this.debounceFormSubmitTimer = window.setTimeout(() => {
        this.debounceFormSubmitTimer = null;
      }, DEBOUNCE_TIMEOUT_IN_SECONDS * 1e3);
    }
  };
  Button.moduleName = "govuk-button";
  Button.defaults = Object.freeze({
    preventDoubleClick: false
  });
  Button.schema = Object.freeze({
    properties: {
      preventDoubleClick: {
        type: "boolean"
      }
    }
  });

  // node_modules/govuk-frontend/dist/govuk/common/closest-attribute-value.mjs
  function closestAttributeValue($element, attributeName) {
    const $closestElementWithAttribute = $element.closest(`[${attributeName}]`);
    return $closestElementWithAttribute ? $closestElementWithAttribute.getAttribute(attributeName) : null;
  }

  // node_modules/govuk-frontend/dist/govuk/components/character-count/character-count.mjs
  var CharacterCount = class _CharacterCount extends ConfigurableComponent {
    [configOverride](datasetConfig) {
      let configOverrides = {};
      if ("maxwords" in datasetConfig || "maxlength" in datasetConfig) {
        configOverrides = {
          maxlength: void 0,
          maxwords: void 0
        };
      }
      return configOverrides;
    }
    /**
     * @param {Element | null} $root - HTML element to use for character count
     * @param {CharacterCountConfig} [config] - Character count config
     */
    constructor($root, config = {}) {
      var _ref, _this$config$maxwords;
      super($root, config);
      this.$textarea = void 0;
      this.$visibleCountMessage = void 0;
      this.$screenReaderCountMessage = void 0;
      this.lastInputTimestamp = null;
      this.lastInputValue = "";
      this.valueChecker = null;
      this.i18n = void 0;
      this.maxLength = void 0;
      const $textarea = this.$root.querySelector(".govuk-js-character-count");
      if (!($textarea instanceof HTMLTextAreaElement || $textarea instanceof HTMLInputElement)) {
        throw new ElementError({
          component: _CharacterCount,
          element: $textarea,
          expectedType: "HTMLTextareaElement or HTMLInputElement",
          identifier: "Form field (`.govuk-js-character-count`)"
        });
      }
      const errors = validateConfig(_CharacterCount.schema, this.config);
      if (errors[0]) {
        throw new ConfigError(formatErrorMessage(_CharacterCount, errors[0]));
      }
      this.i18n = new I18n(this.config.i18n, {
        locale: closestAttributeValue(this.$root, "lang")
      });
      this.maxLength = (_ref = (_this$config$maxwords = this.config.maxwords) != null ? _this$config$maxwords : this.config.maxlength) != null ? _ref : Infinity;
      this.$textarea = $textarea;
      const textareaDescriptionId = `${this.$textarea.id}-info`;
      const $textareaDescription = document.getElementById(textareaDescriptionId);
      if (!$textareaDescription) {
        throw new ElementError({
          component: _CharacterCount,
          element: $textareaDescription,
          identifier: `Count message (\`id="${textareaDescriptionId}"\`)`
        });
      }
      if (`${$textareaDescription.textContent}`.match(/^\s*$/)) {
        $textareaDescription.textContent = this.i18n.t("textareaDescription", {
          count: this.maxLength
        });
      }
      this.$textarea.insertAdjacentElement("afterend", $textareaDescription);
      const $screenReaderCountMessage = document.createElement("div");
      $screenReaderCountMessage.className = "govuk-character-count__sr-status govuk-visually-hidden";
      $screenReaderCountMessage.setAttribute("aria-live", "polite");
      this.$screenReaderCountMessage = $screenReaderCountMessage;
      $textareaDescription.insertAdjacentElement("afterend", $screenReaderCountMessage);
      const $visibleCountMessage = document.createElement("div");
      $visibleCountMessage.className = $textareaDescription.className;
      $visibleCountMessage.classList.add("govuk-character-count__status");
      $visibleCountMessage.setAttribute("aria-hidden", "true");
      this.$visibleCountMessage = $visibleCountMessage;
      $textareaDescription.insertAdjacentElement("afterend", $visibleCountMessage);
      $textareaDescription.classList.add("govuk-visually-hidden");
      this.$textarea.removeAttribute("maxlength");
      this.bindChangeEvents();
      window.addEventListener("pageshow", () => this.updateCountMessage());
      this.updateCountMessage();
    }
    bindChangeEvents() {
      this.$textarea.addEventListener("keyup", () => this.handleKeyUp());
      this.$textarea.addEventListener("focus", () => this.handleFocus());
      this.$textarea.addEventListener("blur", () => this.handleBlur());
    }
    handleKeyUp() {
      this.updateVisibleCountMessage();
      this.lastInputTimestamp = Date.now();
    }
    handleFocus() {
      this.valueChecker = window.setInterval(() => {
        if (!this.lastInputTimestamp || Date.now() - 500 >= this.lastInputTimestamp) {
          this.updateIfValueChanged();
        }
      }, 1e3);
    }
    handleBlur() {
      if (this.valueChecker) {
        window.clearInterval(this.valueChecker);
      }
    }
    updateIfValueChanged() {
      if (this.$textarea.value !== this.lastInputValue) {
        this.lastInputValue = this.$textarea.value;
        this.updateCountMessage();
      }
    }
    updateCountMessage() {
      this.updateVisibleCountMessage();
      this.updateScreenReaderCountMessage();
    }
    updateVisibleCountMessage() {
      const remainingNumber = this.maxLength - this.count(this.$textarea.value);
      const isError = remainingNumber < 0;
      this.$visibleCountMessage.classList.toggle("govuk-character-count__message--disabled", !this.isOverThreshold());
      this.$textarea.classList.toggle("govuk-textarea--error", isError);
      this.$visibleCountMessage.classList.toggle("govuk-error-message", isError);
      this.$visibleCountMessage.classList.toggle("govuk-hint", !isError);
      this.$visibleCountMessage.textContent = this.getCountMessage();
    }
    updateScreenReaderCountMessage() {
      if (this.isOverThreshold()) {
        this.$screenReaderCountMessage.removeAttribute("aria-hidden");
      } else {
        this.$screenReaderCountMessage.setAttribute("aria-hidden", "true");
      }
      this.$screenReaderCountMessage.textContent = this.getCountMessage();
    }
    count(text) {
      if (this.config.maxwords) {
        var _text$match;
        const tokens = (_text$match = text.match(/\S+/g)) != null ? _text$match : [];
        return tokens.length;
      }
      return text.length;
    }
    getCountMessage() {
      const remainingNumber = this.maxLength - this.count(this.$textarea.value);
      const countType = this.config.maxwords ? "words" : "characters";
      return this.formatCountMessage(remainingNumber, countType);
    }
    formatCountMessage(remainingNumber, countType) {
      if (remainingNumber === 0) {
        return this.i18n.t(`${countType}AtLimit`);
      }
      const translationKeySuffix = remainingNumber < 0 ? "OverLimit" : "UnderLimit";
      return this.i18n.t(`${countType}${translationKeySuffix}`, {
        count: Math.abs(remainingNumber)
      });
    }
    isOverThreshold() {
      if (!this.config.threshold) {
        return true;
      }
      const currentLength = this.count(this.$textarea.value);
      const maxLength = this.maxLength;
      const thresholdValue = maxLength * this.config.threshold / 100;
      return thresholdValue <= currentLength;
    }
  };
  CharacterCount.moduleName = "govuk-character-count";
  CharacterCount.defaults = Object.freeze({
    threshold: 0,
    i18n: {
      charactersUnderLimit: {
        one: "You have %{count} character remaining",
        other: "You have %{count} characters remaining"
      },
      charactersAtLimit: "You have 0 characters remaining",
      charactersOverLimit: {
        one: "You have %{count} character too many",
        other: "You have %{count} characters too many"
      },
      wordsUnderLimit: {
        one: "You have %{count} word remaining",
        other: "You have %{count} words remaining"
      },
      wordsAtLimit: "You have 0 words remaining",
      wordsOverLimit: {
        one: "You have %{count} word too many",
        other: "You have %{count} words too many"
      },
      textareaDescription: {
        other: ""
      }
    }
  });
  CharacterCount.schema = Object.freeze({
    properties: {
      i18n: {
        type: "object"
      },
      maxwords: {
        type: "number"
      },
      maxlength: {
        type: "number"
      },
      threshold: {
        type: "number"
      }
    },
    anyOf: [{
      required: ["maxwords"],
      errorMessage: 'Either "maxlength" or "maxwords" must be provided'
    }, {
      required: ["maxlength"],
      errorMessage: 'Either "maxlength" or "maxwords" must be provided'
    }]
  });

  // node_modules/govuk-frontend/dist/govuk/components/checkboxes/checkboxes.mjs
  var Checkboxes = class _Checkboxes extends Component {
    /**
     * Checkboxes can be associated with a 'conditionally revealed' content block
     * – for example, a checkbox for 'Phone' could reveal an additional form field
     * for the user to enter their phone number.
     *
     * These associations are made using a `data-aria-controls` attribute, which
     * is promoted to an aria-controls attribute during initialisation.
     *
     * We also need to restore the state of any conditional reveals on the page
     * (for example if the user has navigated back), and set up event handlers to
     * keep the reveal in sync with the checkbox state.
     *
     * @param {Element | null} $root - HTML element to use for checkboxes
     */
    constructor($root) {
      super($root);
      this.$inputs = void 0;
      const $inputs = this.$root.querySelectorAll('input[type="checkbox"]');
      if (!$inputs.length) {
        throw new ElementError({
          component: _Checkboxes,
          identifier: 'Form inputs (`<input type="checkbox">`)'
        });
      }
      this.$inputs = $inputs;
      this.$inputs.forEach(($input) => {
        const targetId = $input.getAttribute("data-aria-controls");
        if (!targetId) {
          return;
        }
        if (!document.getElementById(targetId)) {
          throw new ElementError({
            component: _Checkboxes,
            identifier: `Conditional reveal (\`id="${targetId}"\`)`
          });
        }
        $input.setAttribute("aria-controls", targetId);
        $input.removeAttribute("data-aria-controls");
      });
      window.addEventListener("pageshow", () => this.syncAllConditionalReveals());
      this.syncAllConditionalReveals();
      this.$root.addEventListener("click", (event) => this.handleClick(event));
    }
    syncAllConditionalReveals() {
      this.$inputs.forEach(($input) => this.syncConditionalRevealWithInputState($input));
    }
    syncConditionalRevealWithInputState($input) {
      const targetId = $input.getAttribute("aria-controls");
      if (!targetId) {
        return;
      }
      const $target = document.getElementById(targetId);
      if ($target != null && $target.classList.contains("govuk-checkboxes__conditional")) {
        const inputIsChecked = $input.checked;
        $input.setAttribute("aria-expanded", inputIsChecked.toString());
        $target.classList.toggle("govuk-checkboxes__conditional--hidden", !inputIsChecked);
      }
    }
    unCheckAllInputsExcept($input) {
      const allInputsWithSameName = document.querySelectorAll(`input[type="checkbox"][name="${$input.name}"]`);
      allInputsWithSameName.forEach(($inputWithSameName) => {
        const hasSameFormOwner = $input.form === $inputWithSameName.form;
        if (hasSameFormOwner && $inputWithSameName !== $input) {
          $inputWithSameName.checked = false;
          this.syncConditionalRevealWithInputState($inputWithSameName);
        }
      });
    }
    unCheckExclusiveInputs($input) {
      const allInputsWithSameNameAndExclusiveBehaviour = document.querySelectorAll(`input[data-behaviour="exclusive"][type="checkbox"][name="${$input.name}"]`);
      allInputsWithSameNameAndExclusiveBehaviour.forEach(($exclusiveInput) => {
        const hasSameFormOwner = $input.form === $exclusiveInput.form;
        if (hasSameFormOwner) {
          $exclusiveInput.checked = false;
          this.syncConditionalRevealWithInputState($exclusiveInput);
        }
      });
    }
    handleClick(event) {
      const $clickedInput = event.target;
      if (!($clickedInput instanceof HTMLInputElement) || $clickedInput.type !== "checkbox") {
        return;
      }
      const hasAriaControls = $clickedInput.getAttribute("aria-controls");
      if (hasAriaControls) {
        this.syncConditionalRevealWithInputState($clickedInput);
      }
      if (!$clickedInput.checked) {
        return;
      }
      const hasBehaviourExclusive = $clickedInput.getAttribute("data-behaviour") === "exclusive";
      if (hasBehaviourExclusive) {
        this.unCheckAllInputsExcept($clickedInput);
      } else {
        this.unCheckExclusiveInputs($clickedInput);
      }
    }
  };
  Checkboxes.moduleName = "govuk-checkboxes";

  // node_modules/govuk-frontend/dist/govuk/components/error-summary/error-summary.mjs
  var ErrorSummary = class extends ConfigurableComponent {
    /**
     * @param {Element | null} $root - HTML element to use for error summary
     * @param {ErrorSummaryConfig} [config] - Error summary config
     */
    constructor($root, config = {}) {
      super($root, config);
      if (!this.config.disableAutoFocus) {
        setFocus(this.$root);
      }
      this.$root.addEventListener("click", (event) => this.handleClick(event));
    }
    handleClick(event) {
      const $target = event.target;
      if ($target && this.focusTarget($target)) {
        event.preventDefault();
      }
    }
    focusTarget($target) {
      if (!($target instanceof HTMLAnchorElement)) {
        return false;
      }
      const inputId = getFragmentFromUrl($target.href);
      if (!inputId) {
        return false;
      }
      const $input = document.getElementById(inputId);
      if (!$input) {
        return false;
      }
      const $legendOrLabel = this.getAssociatedLegendOrLabel($input);
      if (!$legendOrLabel) {
        return false;
      }
      $legendOrLabel.scrollIntoView();
      $input.focus({
        preventScroll: true
      });
      return true;
    }
    getAssociatedLegendOrLabel($input) {
      var _document$querySelect;
      const $fieldset = $input.closest("fieldset");
      if ($fieldset) {
        const $legends = $fieldset.getElementsByTagName("legend");
        if ($legends.length) {
          const $candidateLegend = $legends[0];
          if ($input instanceof HTMLInputElement && ($input.type === "checkbox" || $input.type === "radio")) {
            return $candidateLegend;
          }
          const legendTop = $candidateLegend.getBoundingClientRect().top;
          const inputRect = $input.getBoundingClientRect();
          if (inputRect.height && window.innerHeight) {
            const inputBottom = inputRect.top + inputRect.height;
            if (inputBottom - legendTop < window.innerHeight / 2) {
              return $candidateLegend;
            }
          }
        }
      }
      return (_document$querySelect = document.querySelector(`label[for='${$input.getAttribute("id")}']`)) != null ? _document$querySelect : $input.closest("label");
    }
  };
  ErrorSummary.moduleName = "govuk-error-summary";
  ErrorSummary.defaults = Object.freeze({
    disableAutoFocus: false
  });
  ErrorSummary.schema = Object.freeze({
    properties: {
      disableAutoFocus: {
        type: "boolean"
      }
    }
  });

  // node_modules/govuk-frontend/dist/govuk/components/exit-this-page/exit-this-page.mjs
  var ExitThisPage = class _ExitThisPage extends ConfigurableComponent {
    /**
     * @param {Element | null} $root - HTML element that wraps the Exit This Page button
     * @param {ExitThisPageConfig} [config] - Exit This Page config
     */
    constructor($root, config = {}) {
      super($root, config);
      this.i18n = void 0;
      this.$button = void 0;
      this.$skiplinkButton = null;
      this.$updateSpan = null;
      this.$indicatorContainer = null;
      this.$overlay = null;
      this.keypressCounter = 0;
      this.lastKeyWasModified = false;
      this.timeoutTime = 5e3;
      this.keypressTimeoutId = null;
      this.timeoutMessageId = null;
      const $button = this.$root.querySelector(".govuk-exit-this-page__button");
      if (!($button instanceof HTMLAnchorElement)) {
        throw new ElementError({
          component: _ExitThisPage,
          element: $button,
          expectedType: "HTMLAnchorElement",
          identifier: "Button (`.govuk-exit-this-page__button`)"
        });
      }
      this.i18n = new I18n(this.config.i18n);
      this.$button = $button;
      const $skiplinkButton = document.querySelector(".govuk-js-exit-this-page-skiplink");
      if ($skiplinkButton instanceof HTMLAnchorElement) {
        this.$skiplinkButton = $skiplinkButton;
      }
      this.buildIndicator();
      this.initUpdateSpan();
      this.initButtonClickHandler();
      if (!("govukFrontendExitThisPageKeypress" in document.body.dataset)) {
        document.addEventListener("keyup", this.handleKeypress.bind(this), true);
        document.body.dataset.govukFrontendExitThisPageKeypress = "true";
      }
      window.addEventListener("pageshow", this.resetPage.bind(this));
    }
    initUpdateSpan() {
      this.$updateSpan = document.createElement("span");
      this.$updateSpan.setAttribute("role", "status");
      this.$updateSpan.className = "govuk-visually-hidden";
      this.$root.appendChild(this.$updateSpan);
    }
    initButtonClickHandler() {
      this.$button.addEventListener("click", this.handleClick.bind(this));
      if (this.$skiplinkButton) {
        this.$skiplinkButton.addEventListener("click", this.handleClick.bind(this));
      }
    }
    buildIndicator() {
      this.$indicatorContainer = document.createElement("div");
      this.$indicatorContainer.className = "govuk-exit-this-page__indicator";
      this.$indicatorContainer.setAttribute("aria-hidden", "true");
      for (let i = 0; i < 3; i++) {
        const $indicator = document.createElement("div");
        $indicator.className = "govuk-exit-this-page__indicator-light";
        this.$indicatorContainer.appendChild($indicator);
      }
      this.$button.appendChild(this.$indicatorContainer);
    }
    updateIndicator() {
      if (!this.$indicatorContainer) {
        return;
      }
      this.$indicatorContainer.classList.toggle("govuk-exit-this-page__indicator--visible", this.keypressCounter > 0);
      const $indicators = this.$indicatorContainer.querySelectorAll(".govuk-exit-this-page__indicator-light");
      $indicators.forEach(($indicator, index) => {
        $indicator.classList.toggle("govuk-exit-this-page__indicator-light--on", index < this.keypressCounter);
      });
    }
    exitPage() {
      if (!this.$updateSpan) {
        return;
      }
      this.$updateSpan.textContent = "";
      document.body.classList.add("govuk-exit-this-page-hide-content");
      this.$overlay = document.createElement("div");
      this.$overlay.className = "govuk-exit-this-page-overlay";
      this.$overlay.setAttribute("role", "alert");
      document.body.appendChild(this.$overlay);
      this.$overlay.textContent = this.i18n.t("activated");
      window.location.href = this.$button.href;
    }
    handleClick(event) {
      event.preventDefault();
      this.exitPage();
    }
    handleKeypress(event) {
      if (!this.$updateSpan) {
        return;
      }
      if (event.key === "Shift" && !this.lastKeyWasModified) {
        this.keypressCounter += 1;
        this.updateIndicator();
        if (this.timeoutMessageId) {
          window.clearTimeout(this.timeoutMessageId);
          this.timeoutMessageId = null;
        }
        if (this.keypressCounter >= 3) {
          this.keypressCounter = 0;
          if (this.keypressTimeoutId) {
            window.clearTimeout(this.keypressTimeoutId);
            this.keypressTimeoutId = null;
          }
          this.exitPage();
        } else {
          if (this.keypressCounter === 1) {
            this.$updateSpan.textContent = this.i18n.t("pressTwoMoreTimes");
          } else {
            this.$updateSpan.textContent = this.i18n.t("pressOneMoreTime");
          }
        }
        this.setKeypressTimer();
      } else if (this.keypressTimeoutId) {
        this.resetKeypressTimer();
      }
      this.lastKeyWasModified = event.shiftKey;
    }
    setKeypressTimer() {
      if (this.keypressTimeoutId) {
        window.clearTimeout(this.keypressTimeoutId);
      }
      this.keypressTimeoutId = window.setTimeout(this.resetKeypressTimer.bind(this), this.timeoutTime);
    }
    resetKeypressTimer() {
      if (!this.$updateSpan) {
        return;
      }
      if (this.keypressTimeoutId) {
        window.clearTimeout(this.keypressTimeoutId);
        this.keypressTimeoutId = null;
      }
      const $updateSpan = this.$updateSpan;
      this.keypressCounter = 0;
      $updateSpan.textContent = this.i18n.t("timedOut");
      this.timeoutMessageId = window.setTimeout(() => {
        $updateSpan.textContent = "";
      }, this.timeoutTime);
      this.updateIndicator();
    }
    resetPage() {
      document.body.classList.remove("govuk-exit-this-page-hide-content");
      if (this.$overlay) {
        this.$overlay.remove();
        this.$overlay = null;
      }
      if (this.$updateSpan) {
        this.$updateSpan.setAttribute("role", "status");
        this.$updateSpan.textContent = "";
      }
      this.updateIndicator();
      if (this.keypressTimeoutId) {
        window.clearTimeout(this.keypressTimeoutId);
      }
      if (this.timeoutMessageId) {
        window.clearTimeout(this.timeoutMessageId);
      }
    }
  };
  ExitThisPage.moduleName = "govuk-exit-this-page";
  ExitThisPage.defaults = Object.freeze({
    i18n: {
      activated: "Loading.",
      timedOut: "Exit this page expired.",
      pressTwoMoreTimes: "Shift, press 2 more times to exit.",
      pressOneMoreTime: "Shift, press 1 more time to exit."
    }
  });
  ExitThisPage.schema = Object.freeze({
    properties: {
      i18n: {
        type: "object"
      }
    }
  });

  // node_modules/govuk-frontend/dist/govuk/components/file-upload/file-upload.mjs
  var FileUpload = class _FileUpload extends ConfigurableComponent {
    /**
     * @param {Element | null} $root - File input element
     * @param {FileUploadConfig} [config] - File Upload config
     */
    constructor($root, config = {}) {
      super($root, config);
      this.$input = void 0;
      this.$button = void 0;
      this.$status = void 0;
      this.i18n = void 0;
      this.id = void 0;
      const $input = this.$root.querySelector("input");
      if ($input === null) {
        throw new ElementError({
          component: _FileUpload,
          identifier: 'File inputs (`<input type="file">`)'
        });
      }
      if ($input.type !== "file") {
        throw new ElementError(formatErrorMessage(_FileUpload, 'File input (`<input type="file">`) attribute (`type`) is not `file`'));
      }
      this.$input = $input;
      this.$input.setAttribute("hidden", "true");
      if (!this.$input.id) {
        throw new ElementError({
          component: _FileUpload,
          identifier: 'File input (`<input type="file">`) attribute (`id`)'
        });
      }
      this.id = this.$input.id;
      this.i18n = new I18n(this.config.i18n, {
        locale: closestAttributeValue(this.$root, "lang")
      });
      const $label = this.findLabel();
      if (!$label.id) {
        $label.id = `${this.id}-label`;
      }
      this.$input.id = `${this.id}-input`;
      const $button = document.createElement("button");
      $button.classList.add("govuk-file-upload-button");
      $button.type = "button";
      $button.id = this.id;
      $button.classList.add("govuk-file-upload-button--empty");
      const ariaDescribedBy = this.$input.getAttribute("aria-describedby");
      if (ariaDescribedBy) {
        $button.setAttribute("aria-describedby", ariaDescribedBy);
      }
      const $status = document.createElement("span");
      $status.className = "govuk-body govuk-file-upload-button__status";
      $status.setAttribute("aria-live", "polite");
      $status.innerText = this.i18n.t("noFileChosen");
      $button.appendChild($status);
      const commaSpan = document.createElement("span");
      commaSpan.className = "govuk-visually-hidden";
      commaSpan.innerText = ", ";
      commaSpan.id = `${this.id}-comma`;
      $button.appendChild(commaSpan);
      const containerSpan = document.createElement("span");
      containerSpan.className = "govuk-file-upload-button__pseudo-button-container";
      const buttonSpan = document.createElement("span");
      buttonSpan.className = "govuk-button govuk-button--secondary govuk-file-upload-button__pseudo-button";
      buttonSpan.innerText = this.i18n.t("chooseFilesButton");
      containerSpan.appendChild(buttonSpan);
      containerSpan.insertAdjacentText("beforeend", " ");
      const instructionSpan = document.createElement("span");
      instructionSpan.className = "govuk-body govuk-file-upload-button__instruction";
      instructionSpan.innerText = this.i18n.t("dropInstruction");
      containerSpan.appendChild(instructionSpan);
      $button.appendChild(containerSpan);
      $button.setAttribute("aria-labelledby", `${$label.id} ${commaSpan.id} ${$button.id}`);
      $button.addEventListener("click", this.onClick.bind(this));
      $button.addEventListener("dragover", (event) => {
        event.preventDefault();
      });
      this.$root.insertAdjacentElement("afterbegin", $button);
      this.$input.setAttribute("tabindex", "-1");
      this.$input.setAttribute("aria-hidden", "true");
      this.$button = $button;
      this.$status = $status;
      this.$input.addEventListener("change", this.onChange.bind(this));
      this.updateDisabledState();
      this.observeDisabledState();
      this.$announcements = document.createElement("span");
      this.$announcements.classList.add("govuk-file-upload-announcements");
      this.$announcements.classList.add("govuk-visually-hidden");
      this.$announcements.setAttribute("aria-live", "assertive");
      this.$root.insertAdjacentElement("afterend", this.$announcements);
      this.$button.addEventListener("drop", this.onDrop.bind(this));
      document.addEventListener("dragenter", this.updateDropzoneVisibility.bind(this));
      document.addEventListener("dragenter", () => {
        this.enteredAnotherElement = true;
      });
      document.addEventListener("dragleave", () => {
        if (!this.enteredAnotherElement && !this.$button.disabled) {
          this.hideDraggingState();
          this.$announcements.innerText = this.i18n.t("leftDropZone");
        }
        this.enteredAnotherElement = false;
      });
    }
    /**
     * Updates the visibility of the dropzone as users enters the various elements on the page
     *
     * @param {DragEvent} event - The `dragenter` event
     */
    updateDropzoneVisibility(event) {
      if (this.$button.disabled) return;
      if (event.target instanceof Node) {
        if (this.$root.contains(event.target)) {
          if (event.dataTransfer && isContainingFiles(event.dataTransfer)) {
            if (!this.$button.classList.contains("govuk-file-upload-button--dragging")) {
              this.showDraggingState();
              this.$announcements.innerText = this.i18n.t("enteredDropZone");
            }
          }
        } else {
          if (this.$button.classList.contains("govuk-file-upload-button--dragging")) {
            this.hideDraggingState();
            this.$announcements.innerText = this.i18n.t("leftDropZone");
          }
        }
      }
    }
    showDraggingState() {
      this.$button.classList.add("govuk-file-upload-button--dragging");
    }
    hideDraggingState() {
      this.$button.classList.remove("govuk-file-upload-button--dragging");
    }
    /**
     * Handles user dropping on the component
     *
     * @param {DragEvent} event - The `dragenter` event
     */
    onDrop(event) {
      event.preventDefault();
      if (event.dataTransfer && isContainingFiles(event.dataTransfer)) {
        this.$input.files = event.dataTransfer.files;
        this.$input.dispatchEvent(new CustomEvent("change"));
        this.hideDraggingState();
      }
    }
    onChange() {
      const fileCount = this.$input.files.length;
      if (fileCount === 0) {
        this.$status.innerText = this.i18n.t("noFileChosen");
        this.$button.classList.add("govuk-file-upload-button--empty");
      } else {
        if (fileCount === 1) {
          this.$status.innerText = this.$input.files[0].name;
        } else {
          this.$status.innerText = this.i18n.t("multipleFilesChosen", {
            count: fileCount
          });
        }
        this.$button.classList.remove("govuk-file-upload-button--empty");
      }
    }
    findLabel() {
      const $label = document.querySelector(`label[for="${this.$input.id}"]`);
      if (!$label) {
        throw new ElementError({
          component: _FileUpload,
          identifier: `Field label (\`<label for=${this.$input.id}>\`)`
        });
      }
      return $label;
    }
    onClick() {
      this.$input.click();
    }
    observeDisabledState() {
      const observer = new MutationObserver((mutationList) => {
        for (const mutation of mutationList) {
          if (mutation.type === "attributes" && mutation.attributeName === "disabled") {
            this.updateDisabledState();
          }
        }
      });
      observer.observe(this.$input, {
        attributes: true
      });
    }
    updateDisabledState() {
      this.$button.disabled = this.$input.disabled;
      this.$root.classList.toggle("govuk-drop-zone--disabled", this.$button.disabled);
    }
  };
  FileUpload.moduleName = "govuk-file-upload";
  FileUpload.defaults = Object.freeze({
    i18n: {
      chooseFilesButton: "Choose file",
      dropInstruction: "or drop file",
      noFileChosen: "No file chosen",
      multipleFilesChosen: {
        one: "%{count} file chosen",
        other: "%{count} files chosen"
      },
      enteredDropZone: "Entered drop zone",
      leftDropZone: "Left drop zone"
    }
  });
  FileUpload.schema = Object.freeze({
    properties: {
      i18n: {
        type: "object"
      }
    }
  });
  function isContainingFiles(dataTransfer) {
    const hasNoTypesInfo = dataTransfer.types.length === 0;
    const isDraggingFiles = dataTransfer.types.some((type) => type === "Files");
    return hasNoTypesInfo || isDraggingFiles;
  }

  // node_modules/govuk-frontend/dist/govuk/components/header/header.mjs
  var Header = class _Header extends Component {
    /**
     * Apply a matchMedia for desktop which will trigger a state sync if the
     * browser viewport moves between states.
     *
     * @param {Element | null} $root - HTML element to use for header
     */
    constructor($root) {
      super($root);
      this.$menuButton = void 0;
      this.$menu = void 0;
      this.menuIsOpen = false;
      this.mql = null;
      const $menuButton = this.$root.querySelector(".govuk-js-header-toggle");
      if (!$menuButton) {
        return this;
      }
      const menuId = $menuButton.getAttribute("aria-controls");
      if (!menuId) {
        throw new ElementError({
          component: _Header,
          identifier: 'Navigation button (`<button class="govuk-js-header-toggle">`) attribute (`aria-controls`)'
        });
      }
      const $menu = document.getElementById(menuId);
      if (!$menu) {
        throw new ElementError({
          component: _Header,
          element: $menu,
          identifier: `Navigation (\`<ul id="${menuId}">\`)`
        });
      }
      this.$menu = $menu;
      this.$menuButton = $menuButton;
      this.setupResponsiveChecks();
      this.$menuButton.addEventListener("click", () => this.handleMenuButtonClick());
    }
    setupResponsiveChecks() {
      const breakpoint = getBreakpoint("desktop");
      if (!breakpoint.value) {
        throw new ElementError({
          component: _Header,
          identifier: `CSS custom property (\`${breakpoint.property}\`) on pseudo-class \`:root\``
        });
      }
      this.mql = window.matchMedia(`(min-width: ${breakpoint.value})`);
      if ("addEventListener" in this.mql) {
        this.mql.addEventListener("change", () => this.checkMode());
      } else {
        this.mql.addListener(() => this.checkMode());
      }
      this.checkMode();
    }
    checkMode() {
      if (!this.mql || !this.$menu || !this.$menuButton) {
        return;
      }
      if (this.mql.matches) {
        this.$menu.removeAttribute("hidden");
        this.$menuButton.setAttribute("hidden", "");
      } else {
        this.$menuButton.removeAttribute("hidden");
        this.$menuButton.setAttribute("aria-expanded", this.menuIsOpen.toString());
        if (this.menuIsOpen) {
          this.$menu.removeAttribute("hidden");
        } else {
          this.$menu.setAttribute("hidden", "");
        }
      }
    }
    handleMenuButtonClick() {
      this.menuIsOpen = !this.menuIsOpen;
      this.checkMode();
    }
  };
  Header.moduleName = "govuk-header";

  // node_modules/govuk-frontend/dist/govuk/components/notification-banner/notification-banner.mjs
  var NotificationBanner = class extends ConfigurableComponent {
    /**
     * @param {Element | null} $root - HTML element to use for notification banner
     * @param {NotificationBannerConfig} [config] - Notification banner config
     */
    constructor($root, config = {}) {
      super($root, config);
      if (this.$root.getAttribute("role") === "alert" && !this.config.disableAutoFocus) {
        setFocus(this.$root);
      }
    }
  };
  NotificationBanner.moduleName = "govuk-notification-banner";
  NotificationBanner.defaults = Object.freeze({
    disableAutoFocus: false
  });
  NotificationBanner.schema = Object.freeze({
    properties: {
      disableAutoFocus: {
        type: "boolean"
      }
    }
  });

  // node_modules/govuk-frontend/dist/govuk/components/password-input/password-input.mjs
  var PasswordInput = class _PasswordInput extends ConfigurableComponent {
    /**
     * @param {Element | null} $root - HTML element to use for password input
     * @param {PasswordInputConfig} [config] - Password input config
     */
    constructor($root, config = {}) {
      super($root, config);
      this.i18n = void 0;
      this.$input = void 0;
      this.$showHideButton = void 0;
      this.$screenReaderStatusMessage = void 0;
      const $input = this.$root.querySelector(".govuk-js-password-input-input");
      if (!($input instanceof HTMLInputElement)) {
        throw new ElementError({
          component: _PasswordInput,
          element: $input,
          expectedType: "HTMLInputElement",
          identifier: "Form field (`.govuk-js-password-input-input`)"
        });
      }
      if ($input.type !== "password") {
        throw new ElementError("Password input: Form field (`.govuk-js-password-input-input`) must be of type `password`.");
      }
      const $showHideButton = this.$root.querySelector(".govuk-js-password-input-toggle");
      if (!($showHideButton instanceof HTMLButtonElement)) {
        throw new ElementError({
          component: _PasswordInput,
          element: $showHideButton,
          expectedType: "HTMLButtonElement",
          identifier: "Button (`.govuk-js-password-input-toggle`)"
        });
      }
      if ($showHideButton.type !== "button") {
        throw new ElementError("Password input: Button (`.govuk-js-password-input-toggle`) must be of type `button`.");
      }
      this.$input = $input;
      this.$showHideButton = $showHideButton;
      this.i18n = new I18n(this.config.i18n, {
        locale: closestAttributeValue(this.$root, "lang")
      });
      this.$showHideButton.removeAttribute("hidden");
      const $screenReaderStatusMessage = document.createElement("div");
      $screenReaderStatusMessage.className = "govuk-password-input__sr-status govuk-visually-hidden";
      $screenReaderStatusMessage.setAttribute("aria-live", "polite");
      this.$screenReaderStatusMessage = $screenReaderStatusMessage;
      this.$input.insertAdjacentElement("afterend", $screenReaderStatusMessage);
      this.$showHideButton.addEventListener("click", this.toggle.bind(this));
      if (this.$input.form) {
        this.$input.form.addEventListener("submit", () => this.hide());
      }
      window.addEventListener("pageshow", (event) => {
        if (event.persisted && this.$input.type !== "password") {
          this.hide();
        }
      });
      this.hide();
    }
    toggle(event) {
      event.preventDefault();
      if (this.$input.type === "password") {
        this.show();
        return;
      }
      this.hide();
    }
    show() {
      this.setType("text");
    }
    hide() {
      this.setType("password");
    }
    setType(type) {
      if (type === this.$input.type) {
        return;
      }
      this.$input.setAttribute("type", type);
      const isHidden = type === "password";
      const prefixButton = isHidden ? "show" : "hide";
      const prefixStatus = isHidden ? "passwordHidden" : "passwordShown";
      this.$showHideButton.innerText = this.i18n.t(`${prefixButton}Password`);
      this.$showHideButton.setAttribute("aria-label", this.i18n.t(`${prefixButton}PasswordAriaLabel`));
      this.$screenReaderStatusMessage.innerText = this.i18n.t(`${prefixStatus}Announcement`);
    }
  };
  PasswordInput.moduleName = "govuk-password-input";
  PasswordInput.defaults = Object.freeze({
    i18n: {
      showPassword: "Show",
      hidePassword: "Hide",
      showPasswordAriaLabel: "Show password",
      hidePasswordAriaLabel: "Hide password",
      passwordShownAnnouncement: "Your password is visible",
      passwordHiddenAnnouncement: "Your password is hidden"
    }
  });
  PasswordInput.schema = Object.freeze({
    properties: {
      i18n: {
        type: "object"
      }
    }
  });

  // node_modules/govuk-frontend/dist/govuk/components/radios/radios.mjs
  var Radios = class _Radios extends Component {
    /**
     * Radios can be associated with a 'conditionally revealed' content block –
     * for example, a radio for 'Phone' could reveal an additional form field for
     * the user to enter their phone number.
     *
     * These associations are made using a `data-aria-controls` attribute, which
     * is promoted to an aria-controls attribute during initialisation.
     *
     * We also need to restore the state of any conditional reveals on the page
     * (for example if the user has navigated back), and set up event handlers to
     * keep the reveal in sync with the radio state.
     *
     * @param {Element | null} $root - HTML element to use for radios
     */
    constructor($root) {
      super($root);
      this.$inputs = void 0;
      const $inputs = this.$root.querySelectorAll('input[type="radio"]');
      if (!$inputs.length) {
        throw new ElementError({
          component: _Radios,
          identifier: 'Form inputs (`<input type="radio">`)'
        });
      }
      this.$inputs = $inputs;
      this.$inputs.forEach(($input) => {
        const targetId = $input.getAttribute("data-aria-controls");
        if (!targetId) {
          return;
        }
        if (!document.getElementById(targetId)) {
          throw new ElementError({
            component: _Radios,
            identifier: `Conditional reveal (\`id="${targetId}"\`)`
          });
        }
        $input.setAttribute("aria-controls", targetId);
        $input.removeAttribute("data-aria-controls");
      });
      window.addEventListener("pageshow", () => this.syncAllConditionalReveals());
      this.syncAllConditionalReveals();
      this.$root.addEventListener("click", (event) => this.handleClick(event));
    }
    syncAllConditionalReveals() {
      this.$inputs.forEach(($input) => this.syncConditionalRevealWithInputState($input));
    }
    syncConditionalRevealWithInputState($input) {
      const targetId = $input.getAttribute("aria-controls");
      if (!targetId) {
        return;
      }
      const $target = document.getElementById(targetId);
      if ($target != null && $target.classList.contains("govuk-radios__conditional")) {
        const inputIsChecked = $input.checked;
        $input.setAttribute("aria-expanded", inputIsChecked.toString());
        $target.classList.toggle("govuk-radios__conditional--hidden", !inputIsChecked);
      }
    }
    handleClick(event) {
      const $clickedInput = event.target;
      if (!($clickedInput instanceof HTMLInputElement) || $clickedInput.type !== "radio") {
        return;
      }
      const $allInputs = document.querySelectorAll('input[type="radio"][aria-controls]');
      const $clickedInputForm = $clickedInput.form;
      const $clickedInputName = $clickedInput.name;
      $allInputs.forEach(($input) => {
        const hasSameFormOwner = $input.form === $clickedInputForm;
        const hasSameName = $input.name === $clickedInputName;
        if (hasSameName && hasSameFormOwner) {
          this.syncConditionalRevealWithInputState($input);
        }
      });
    }
  };
  Radios.moduleName = "govuk-radios";

  // node_modules/govuk-frontend/dist/govuk/components/service-navigation/service-navigation.mjs
  var ServiceNavigation = class _ServiceNavigation extends Component {
    /**
     * @param {Element | null} $root - HTML element to use for header
     */
    constructor($root) {
      super($root);
      this.$menuButton = void 0;
      this.$menu = void 0;
      this.menuIsOpen = false;
      this.mql = null;
      const $menuButton = this.$root.querySelector(".govuk-js-service-navigation-toggle");
      if (!$menuButton) {
        return this;
      }
      const menuId = $menuButton.getAttribute("aria-controls");
      if (!menuId) {
        throw new ElementError({
          component: _ServiceNavigation,
          identifier: 'Navigation button (`<button class="govuk-js-service-navigation-toggle">`) attribute (`aria-controls`)'
        });
      }
      const $menu = document.getElementById(menuId);
      if (!$menu) {
        throw new ElementError({
          component: _ServiceNavigation,
          element: $menu,
          identifier: `Navigation (\`<ul id="${menuId}">\`)`
        });
      }
      this.$menu = $menu;
      this.$menuButton = $menuButton;
      this.setupResponsiveChecks();
      this.$menuButton.addEventListener("click", () => this.handleMenuButtonClick());
    }
    setupResponsiveChecks() {
      const breakpoint = getBreakpoint("tablet");
      if (!breakpoint.value) {
        throw new ElementError({
          component: _ServiceNavigation,
          identifier: `CSS custom property (\`${breakpoint.property}\`) on pseudo-class \`:root\``
        });
      }
      this.mql = window.matchMedia(`(min-width: ${breakpoint.value})`);
      if ("addEventListener" in this.mql) {
        this.mql.addEventListener("change", () => this.checkMode());
      } else {
        this.mql.addListener(() => this.checkMode());
      }
      this.checkMode();
    }
    checkMode() {
      if (!this.mql || !this.$menu || !this.$menuButton) {
        return;
      }
      if (this.mql.matches) {
        this.$menu.removeAttribute("hidden");
        this.$menuButton.setAttribute("hidden", "");
      } else {
        this.$menuButton.removeAttribute("hidden");
        this.$menuButton.setAttribute("aria-expanded", this.menuIsOpen.toString());
        if (this.menuIsOpen) {
          this.$menu.removeAttribute("hidden");
        } else {
          this.$menu.setAttribute("hidden", "");
        }
      }
    }
    handleMenuButtonClick() {
      this.menuIsOpen = !this.menuIsOpen;
      this.checkMode();
    }
  };
  ServiceNavigation.moduleName = "govuk-service-navigation";

  // node_modules/govuk-frontend/dist/govuk/components/skip-link/skip-link.mjs
  var SkipLink = class _SkipLink extends Component {
    /**
     * @param {Element | null} $root - HTML element to use for skip link
     * @throws {ElementError} when $root is not set or the wrong type
     * @throws {ElementError} when $root.hash does not contain a hash
     * @throws {ElementError} when the linked element is missing or the wrong type
     */
    constructor($root) {
      var _this$$root$getAttrib;
      super($root);
      const hash = this.$root.hash;
      const href = (_this$$root$getAttrib = this.$root.getAttribute("href")) != null ? _this$$root$getAttrib : "";
      let url;
      try {
        url = new window.URL(this.$root.href);
      } catch (error2) {
        throw new ElementError(`Skip link: Target link (\`href="${href}"\`) is invalid`);
      }
      if (url.origin !== window.location.origin || url.pathname !== window.location.pathname) {
        return;
      }
      const linkedElementId = getFragmentFromUrl(hash);
      if (!linkedElementId) {
        throw new ElementError(`Skip link: Target link (\`href="${href}"\`) has no hash fragment`);
      }
      const $linkedElement = document.getElementById(linkedElementId);
      if (!$linkedElement) {
        throw new ElementError({
          component: _SkipLink,
          element: $linkedElement,
          identifier: `Target content (\`id="${linkedElementId}"\`)`
        });
      }
      this.$root.addEventListener("click", () => setFocus($linkedElement, {
        onBeforeFocus() {
          $linkedElement.classList.add("govuk-skip-link-focused-element");
        },
        onBlur() {
          $linkedElement.classList.remove("govuk-skip-link-focused-element");
        }
      }));
    }
  };
  SkipLink.elementType = HTMLAnchorElement;
  SkipLink.moduleName = "govuk-skip-link";

  // node_modules/govuk-frontend/dist/govuk/components/tabs/tabs.mjs
  var Tabs = class _Tabs extends Component {
    /**
     * @param {Element | null} $root - HTML element to use for tabs
     */
    constructor($root) {
      super($root);
      this.$tabs = void 0;
      this.$tabList = void 0;
      this.$tabListItems = void 0;
      this.jsHiddenClass = "govuk-tabs__panel--hidden";
      this.changingHash = false;
      this.boundTabClick = void 0;
      this.boundTabKeydown = void 0;
      this.boundOnHashChange = void 0;
      this.mql = null;
      const $tabs = this.$root.querySelectorAll("a.govuk-tabs__tab");
      if (!$tabs.length) {
        throw new ElementError({
          component: _Tabs,
          identifier: 'Links (`<a class="govuk-tabs__tab">`)'
        });
      }
      this.$tabs = $tabs;
      this.boundTabClick = this.onTabClick.bind(this);
      this.boundTabKeydown = this.onTabKeydown.bind(this);
      this.boundOnHashChange = this.onHashChange.bind(this);
      const $tabList = this.$root.querySelector(".govuk-tabs__list");
      const $tabListItems = this.$root.querySelectorAll("li.govuk-tabs__list-item");
      if (!$tabList) {
        throw new ElementError({
          component: _Tabs,
          identifier: 'List (`<ul class="govuk-tabs__list">`)'
        });
      }
      if (!$tabListItems.length) {
        throw new ElementError({
          component: _Tabs,
          identifier: 'List items (`<li class="govuk-tabs__list-item">`)'
        });
      }
      this.$tabList = $tabList;
      this.$tabListItems = $tabListItems;
      this.setupResponsiveChecks();
    }
    setupResponsiveChecks() {
      const breakpoint = getBreakpoint("tablet");
      if (!breakpoint.value) {
        throw new ElementError({
          component: _Tabs,
          identifier: `CSS custom property (\`${breakpoint.property}\`) on pseudo-class \`:root\``
        });
      }
      this.mql = window.matchMedia(`(min-width: ${breakpoint.value})`);
      if ("addEventListener" in this.mql) {
        this.mql.addEventListener("change", () => this.checkMode());
      } else {
        this.mql.addListener(() => this.checkMode());
      }
      this.checkMode();
    }
    checkMode() {
      var _this$mql;
      if ((_this$mql = this.mql) != null && _this$mql.matches) {
        this.setup();
      } else {
        this.teardown();
      }
    }
    setup() {
      var _this$getTab;
      this.$tabList.setAttribute("role", "tablist");
      this.$tabListItems.forEach(($item) => {
        $item.setAttribute("role", "presentation");
      });
      this.$tabs.forEach(($tab) => {
        this.setAttributes($tab);
        $tab.addEventListener("click", this.boundTabClick, true);
        $tab.addEventListener("keydown", this.boundTabKeydown, true);
        this.hideTab($tab);
      });
      const $activeTab = (_this$getTab = this.getTab(window.location.hash)) != null ? _this$getTab : this.$tabs[0];
      this.showTab($activeTab);
      window.addEventListener("hashchange", this.boundOnHashChange, true);
    }
    teardown() {
      this.$tabList.removeAttribute("role");
      this.$tabListItems.forEach(($item) => {
        $item.removeAttribute("role");
      });
      this.$tabs.forEach(($tab) => {
        $tab.removeEventListener("click", this.boundTabClick, true);
        $tab.removeEventListener("keydown", this.boundTabKeydown, true);
        this.unsetAttributes($tab);
      });
      window.removeEventListener("hashchange", this.boundOnHashChange, true);
    }
    onHashChange() {
      const hash = window.location.hash;
      const $tabWithHash = this.getTab(hash);
      if (!$tabWithHash) {
        return;
      }
      if (this.changingHash) {
        this.changingHash = false;
        return;
      }
      const $previousTab = this.getCurrentTab();
      if (!$previousTab) {
        return;
      }
      this.hideTab($previousTab);
      this.showTab($tabWithHash);
      $tabWithHash.focus();
    }
    hideTab($tab) {
      this.unhighlightTab($tab);
      this.hidePanel($tab);
    }
    showTab($tab) {
      this.highlightTab($tab);
      this.showPanel($tab);
    }
    getTab(hash) {
      return this.$root.querySelector(`a.govuk-tabs__tab[href="${hash}"]`);
    }
    setAttributes($tab) {
      const panelId = getFragmentFromUrl($tab.href);
      if (!panelId) {
        return;
      }
      $tab.setAttribute("id", `tab_${panelId}`);
      $tab.setAttribute("role", "tab");
      $tab.setAttribute("aria-controls", panelId);
      $tab.setAttribute("aria-selected", "false");
      $tab.setAttribute("tabindex", "-1");
      const $panel = this.getPanel($tab);
      if (!$panel) {
        return;
      }
      $panel.setAttribute("role", "tabpanel");
      $panel.setAttribute("aria-labelledby", $tab.id);
      $panel.classList.add(this.jsHiddenClass);
    }
    unsetAttributes($tab) {
      $tab.removeAttribute("id");
      $tab.removeAttribute("role");
      $tab.removeAttribute("aria-controls");
      $tab.removeAttribute("aria-selected");
      $tab.removeAttribute("tabindex");
      const $panel = this.getPanel($tab);
      if (!$panel) {
        return;
      }
      $panel.removeAttribute("role");
      $panel.removeAttribute("aria-labelledby");
      $panel.classList.remove(this.jsHiddenClass);
    }
    onTabClick(event) {
      const $currentTab = this.getCurrentTab();
      const $nextTab = event.currentTarget;
      if (!$currentTab || !($nextTab instanceof HTMLAnchorElement)) {
        return;
      }
      event.preventDefault();
      this.hideTab($currentTab);
      this.showTab($nextTab);
      this.createHistoryEntry($nextTab);
    }
    createHistoryEntry($tab) {
      const $panel = this.getPanel($tab);
      if (!$panel) {
        return;
      }
      const panelId = $panel.id;
      $panel.id = "";
      this.changingHash = true;
      window.location.hash = panelId;
      $panel.id = panelId;
    }
    onTabKeydown(event) {
      switch (event.key) {
        case "ArrowLeft":
        case "Left":
          this.activatePreviousTab();
          event.preventDefault();
          break;
        case "ArrowRight":
        case "Right":
          this.activateNextTab();
          event.preventDefault();
          break;
      }
    }
    activateNextTab() {
      const $currentTab = this.getCurrentTab();
      if (!($currentTab != null && $currentTab.parentElement)) {
        return;
      }
      const $nextTabListItem = $currentTab.parentElement.nextElementSibling;
      if (!$nextTabListItem) {
        return;
      }
      const $nextTab = $nextTabListItem.querySelector("a.govuk-tabs__tab");
      if (!$nextTab) {
        return;
      }
      this.hideTab($currentTab);
      this.showTab($nextTab);
      $nextTab.focus();
      this.createHistoryEntry($nextTab);
    }
    activatePreviousTab() {
      const $currentTab = this.getCurrentTab();
      if (!($currentTab != null && $currentTab.parentElement)) {
        return;
      }
      const $previousTabListItem = $currentTab.parentElement.previousElementSibling;
      if (!$previousTabListItem) {
        return;
      }
      const $previousTab = $previousTabListItem.querySelector("a.govuk-tabs__tab");
      if (!$previousTab) {
        return;
      }
      this.hideTab($currentTab);
      this.showTab($previousTab);
      $previousTab.focus();
      this.createHistoryEntry($previousTab);
    }
    getPanel($tab) {
      const panelId = getFragmentFromUrl($tab.href);
      if (!panelId) {
        return null;
      }
      return this.$root.querySelector(`#${panelId}`);
    }
    showPanel($tab) {
      const $panel = this.getPanel($tab);
      if (!$panel) {
        return;
      }
      $panel.classList.remove(this.jsHiddenClass);
    }
    hidePanel($tab) {
      const $panel = this.getPanel($tab);
      if (!$panel) {
        return;
      }
      $panel.classList.add(this.jsHiddenClass);
    }
    unhighlightTab($tab) {
      if (!$tab.parentElement) {
        return;
      }
      $tab.setAttribute("aria-selected", "false");
      $tab.parentElement.classList.remove("govuk-tabs__list-item--selected");
      $tab.setAttribute("tabindex", "-1");
    }
    highlightTab($tab) {
      if (!$tab.parentElement) {
        return;
      }
      $tab.setAttribute("aria-selected", "true");
      $tab.parentElement.classList.add("govuk-tabs__list-item--selected");
      $tab.setAttribute("tabindex", "0");
    }
    getCurrentTab() {
      return this.$root.querySelector(".govuk-tabs__list-item--selected a.govuk-tabs__tab");
    }
  };
  Tabs.moduleName = "govuk-tabs";

  // node_modules/govuk-frontend/dist/govuk/init.mjs
  function initAll(config) {
    var _config$scope;
    config = typeof config !== "undefined" ? config : {};
    if (!isSupported()) {
      if (config.onError) {
        config.onError(new SupportError(), {
          config
        });
      } else {
        console.log(new SupportError());
      }
      return;
    }
    const components = [[Accordion, config.accordion], [Button, config.button], [CharacterCount, config.characterCount], [Checkboxes], [ErrorSummary, config.errorSummary], [ExitThisPage, config.exitThisPage], [FileUpload, config.fileUpload], [Header], [NotificationBanner, config.notificationBanner], [PasswordInput, config.passwordInput], [Radios], [ServiceNavigation], [SkipLink], [Tabs]];
    const options = {
      scope: (_config$scope = config.scope) != null ? _config$scope : document,
      onError: config.onError
    };
    components.forEach(([Component2, config2]) => {
      createAll(Component2, config2, options);
    });
  }
  function createAll(Component2, config, createAllOptions) {
    let $scope = document;
    let onError;
    if (typeof createAllOptions === "object") {
      var _createAllOptions$sco;
      createAllOptions = createAllOptions;
      $scope = (_createAllOptions$sco = createAllOptions.scope) != null ? _createAllOptions$sco : $scope;
      onError = createAllOptions.onError;
    }
    if (typeof createAllOptions === "function") {
      onError = createAllOptions;
    }
    if (createAllOptions instanceof HTMLElement) {
      $scope = createAllOptions;
    }
    const $elements = $scope.querySelectorAll(`[data-module="${Component2.moduleName}"]`);
    if (!isSupported()) {
      if (onError) {
        onError(new SupportError(), {
          component: Component2,
          config
        });
      } else {
        console.log(new SupportError());
      }
      return [];
    }
    return Array.from($elements).map(($element) => {
      try {
        return typeof config !== "undefined" ? new Component2($element, config) : new Component2($element);
      } catch (error2) {
        if (onError) {
          onError(error2, {
            element: $element,
            component: Component2,
            config
          });
        } else {
          console.log(error2);
        }
        return null;
      }
    }).filter(Boolean);
  }

  // node_modules/@hotwired/stimulus/dist/stimulus.js
  var EventListener = class {
    constructor(eventTarget, eventName, eventOptions) {
      this.eventTarget = eventTarget;
      this.eventName = eventName;
      this.eventOptions = eventOptions;
      this.unorderedBindings = /* @__PURE__ */ new Set();
    }
    connect() {
      this.eventTarget.addEventListener(this.eventName, this, this.eventOptions);
    }
    disconnect() {
      this.eventTarget.removeEventListener(this.eventName, this, this.eventOptions);
    }
    bindingConnected(binding) {
      this.unorderedBindings.add(binding);
    }
    bindingDisconnected(binding) {
      this.unorderedBindings.delete(binding);
    }
    handleEvent(event) {
      const extendedEvent = extendEvent(event);
      for (const binding of this.bindings) {
        if (extendedEvent.immediatePropagationStopped) {
          break;
        } else {
          binding.handleEvent(extendedEvent);
        }
      }
    }
    hasBindings() {
      return this.unorderedBindings.size > 0;
    }
    get bindings() {
      return Array.from(this.unorderedBindings).sort((left, right) => {
        const leftIndex = left.index, rightIndex = right.index;
        return leftIndex < rightIndex ? -1 : leftIndex > rightIndex ? 1 : 0;
      });
    }
  };
  function extendEvent(event) {
    if ("immediatePropagationStopped" in event) {
      return event;
    } else {
      const { stopImmediatePropagation } = event;
      return Object.assign(event, {
        immediatePropagationStopped: false,
        stopImmediatePropagation() {
          this.immediatePropagationStopped = true;
          stopImmediatePropagation.call(this);
        }
      });
    }
  }
  var Dispatcher = class {
    constructor(application) {
      this.application = application;
      this.eventListenerMaps = /* @__PURE__ */ new Map();
      this.started = false;
    }
    start() {
      if (!this.started) {
        this.started = true;
        this.eventListeners.forEach((eventListener) => eventListener.connect());
      }
    }
    stop() {
      if (this.started) {
        this.started = false;
        this.eventListeners.forEach((eventListener) => eventListener.disconnect());
      }
    }
    get eventListeners() {
      return Array.from(this.eventListenerMaps.values()).reduce((listeners, map) => listeners.concat(Array.from(map.values())), []);
    }
    bindingConnected(binding) {
      this.fetchEventListenerForBinding(binding).bindingConnected(binding);
    }
    bindingDisconnected(binding, clearEventListeners = false) {
      this.fetchEventListenerForBinding(binding).bindingDisconnected(binding);
      if (clearEventListeners)
        this.clearEventListenersForBinding(binding);
    }
    handleError(error2, message, detail = {}) {
      this.application.handleError(error2, `Error ${message}`, detail);
    }
    clearEventListenersForBinding(binding) {
      const eventListener = this.fetchEventListenerForBinding(binding);
      if (!eventListener.hasBindings()) {
        eventListener.disconnect();
        this.removeMappedEventListenerFor(binding);
      }
    }
    removeMappedEventListenerFor(binding) {
      const { eventTarget, eventName, eventOptions } = binding;
      const eventListenerMap = this.fetchEventListenerMapForEventTarget(eventTarget);
      const cacheKey = this.cacheKey(eventName, eventOptions);
      eventListenerMap.delete(cacheKey);
      if (eventListenerMap.size == 0)
        this.eventListenerMaps.delete(eventTarget);
    }
    fetchEventListenerForBinding(binding) {
      const { eventTarget, eventName, eventOptions } = binding;
      return this.fetchEventListener(eventTarget, eventName, eventOptions);
    }
    fetchEventListener(eventTarget, eventName, eventOptions) {
      const eventListenerMap = this.fetchEventListenerMapForEventTarget(eventTarget);
      const cacheKey = this.cacheKey(eventName, eventOptions);
      let eventListener = eventListenerMap.get(cacheKey);
      if (!eventListener) {
        eventListener = this.createEventListener(eventTarget, eventName, eventOptions);
        eventListenerMap.set(cacheKey, eventListener);
      }
      return eventListener;
    }
    createEventListener(eventTarget, eventName, eventOptions) {
      const eventListener = new EventListener(eventTarget, eventName, eventOptions);
      if (this.started) {
        eventListener.connect();
      }
      return eventListener;
    }
    fetchEventListenerMapForEventTarget(eventTarget) {
      let eventListenerMap = this.eventListenerMaps.get(eventTarget);
      if (!eventListenerMap) {
        eventListenerMap = /* @__PURE__ */ new Map();
        this.eventListenerMaps.set(eventTarget, eventListenerMap);
      }
      return eventListenerMap;
    }
    cacheKey(eventName, eventOptions) {
      const parts = [eventName];
      Object.keys(eventOptions).sort().forEach((key) => {
        parts.push(`${eventOptions[key] ? "" : "!"}${key}`);
      });
      return parts.join(":");
    }
  };
  var defaultActionDescriptorFilters = {
    stop({ event, value }) {
      if (value)
        event.stopPropagation();
      return true;
    },
    prevent({ event, value }) {
      if (value)
        event.preventDefault();
      return true;
    },
    self({ event, value, element }) {
      if (value) {
        return element === event.target;
      } else {
        return true;
      }
    }
  };
  var descriptorPattern = /^(?:(?:([^.]+?)\+)?(.+?)(?:\.(.+?))?(?:@(window|document))?->)?(.+?)(?:#([^:]+?))(?::(.+))?$/;
  function parseActionDescriptorString(descriptorString) {
    const source = descriptorString.trim();
    const matches = source.match(descriptorPattern) || [];
    let eventName = matches[2];
    let keyFilter = matches[3];
    if (keyFilter && !["keydown", "keyup", "keypress"].includes(eventName)) {
      eventName += `.${keyFilter}`;
      keyFilter = "";
    }
    return {
      eventTarget: parseEventTarget(matches[4]),
      eventName,
      eventOptions: matches[7] ? parseEventOptions(matches[7]) : {},
      identifier: matches[5],
      methodName: matches[6],
      keyFilter: matches[1] || keyFilter
    };
  }
  function parseEventTarget(eventTargetName) {
    if (eventTargetName == "window") {
      return window;
    } else if (eventTargetName == "document") {
      return document;
    }
  }
  function parseEventOptions(eventOptions) {
    return eventOptions.split(":").reduce((options, token) => Object.assign(options, { [token.replace(/^!/, "")]: !/^!/.test(token) }), {});
  }
  function stringifyEventTarget(eventTarget) {
    if (eventTarget == window) {
      return "window";
    } else if (eventTarget == document) {
      return "document";
    }
  }
  function camelize(value) {
    return value.replace(/(?:[_-])([a-z0-9])/g, (_, char) => char.toUpperCase());
  }
  function namespaceCamelize(value) {
    return camelize(value.replace(/--/g, "-").replace(/__/g, "_"));
  }
  function capitalize(value) {
    return value.charAt(0).toUpperCase() + value.slice(1);
  }
  function dasherize(value) {
    return value.replace(/([A-Z])/g, (_, char) => `-${char.toLowerCase()}`);
  }
  function tokenize(value) {
    return value.match(/[^\s]+/g) || [];
  }
  function isSomething(object) {
    return object !== null && object !== void 0;
  }
  function hasProperty(object, property) {
    return Object.prototype.hasOwnProperty.call(object, property);
  }
  var allModifiers = ["meta", "ctrl", "alt", "shift"];
  var Action = class {
    constructor(element, index, descriptor, schema) {
      this.element = element;
      this.index = index;
      this.eventTarget = descriptor.eventTarget || element;
      this.eventName = descriptor.eventName || getDefaultEventNameForElement(element) || error("missing event name");
      this.eventOptions = descriptor.eventOptions || {};
      this.identifier = descriptor.identifier || error("missing identifier");
      this.methodName = descriptor.methodName || error("missing method name");
      this.keyFilter = descriptor.keyFilter || "";
      this.schema = schema;
    }
    static forToken(token, schema) {
      return new this(token.element, token.index, parseActionDescriptorString(token.content), schema);
    }
    toString() {
      const eventFilter = this.keyFilter ? `.${this.keyFilter}` : "";
      const eventTarget = this.eventTargetName ? `@${this.eventTargetName}` : "";
      return `${this.eventName}${eventFilter}${eventTarget}->${this.identifier}#${this.methodName}`;
    }
    shouldIgnoreKeyboardEvent(event) {
      if (!this.keyFilter) {
        return false;
      }
      const filters = this.keyFilter.split("+");
      if (this.keyFilterDissatisfied(event, filters)) {
        return true;
      }
      const standardFilter = filters.filter((key) => !allModifiers.includes(key))[0];
      if (!standardFilter) {
        return false;
      }
      if (!hasProperty(this.keyMappings, standardFilter)) {
        error(`contains unknown key filter: ${this.keyFilter}`);
      }
      return this.keyMappings[standardFilter].toLowerCase() !== event.key.toLowerCase();
    }
    shouldIgnoreMouseEvent(event) {
      if (!this.keyFilter) {
        return false;
      }
      const filters = [this.keyFilter];
      if (this.keyFilterDissatisfied(event, filters)) {
        return true;
      }
      return false;
    }
    get params() {
      const params = {};
      const pattern = new RegExp(`^data-${this.identifier}-(.+)-param$`, "i");
      for (const { name, value } of Array.from(this.element.attributes)) {
        const match = name.match(pattern);
        const key = match && match[1];
        if (key) {
          params[camelize(key)] = typecast(value);
        }
      }
      return params;
    }
    get eventTargetName() {
      return stringifyEventTarget(this.eventTarget);
    }
    get keyMappings() {
      return this.schema.keyMappings;
    }
    keyFilterDissatisfied(event, filters) {
      const [meta, ctrl, alt, shift] = allModifiers.map((modifier) => filters.includes(modifier));
      return event.metaKey !== meta || event.ctrlKey !== ctrl || event.altKey !== alt || event.shiftKey !== shift;
    }
  };
  var defaultEventNames = {
    a: () => "click",
    button: () => "click",
    form: () => "submit",
    details: () => "toggle",
    input: (e) => e.getAttribute("type") == "submit" ? "click" : "input",
    select: () => "change",
    textarea: () => "input"
  };
  function getDefaultEventNameForElement(element) {
    const tagName = element.tagName.toLowerCase();
    if (tagName in defaultEventNames) {
      return defaultEventNames[tagName](element);
    }
  }
  function error(message) {
    throw new Error(message);
  }
  function typecast(value) {
    try {
      return JSON.parse(value);
    } catch (o_O) {
      return value;
    }
  }
  var Binding = class {
    constructor(context, action) {
      this.context = context;
      this.action = action;
    }
    get index() {
      return this.action.index;
    }
    get eventTarget() {
      return this.action.eventTarget;
    }
    get eventOptions() {
      return this.action.eventOptions;
    }
    get identifier() {
      return this.context.identifier;
    }
    handleEvent(event) {
      const actionEvent = this.prepareActionEvent(event);
      if (this.willBeInvokedByEvent(event) && this.applyEventModifiers(actionEvent)) {
        this.invokeWithEvent(actionEvent);
      }
    }
    get eventName() {
      return this.action.eventName;
    }
    get method() {
      const method = this.controller[this.methodName];
      if (typeof method == "function") {
        return method;
      }
      throw new Error(`Action "${this.action}" references undefined method "${this.methodName}"`);
    }
    applyEventModifiers(event) {
      const { element } = this.action;
      const { actionDescriptorFilters } = this.context.application;
      const { controller } = this.context;
      let passes = true;
      for (const [name, value] of Object.entries(this.eventOptions)) {
        if (name in actionDescriptorFilters) {
          const filter = actionDescriptorFilters[name];
          passes = passes && filter({ name, value, event, element, controller });
        } else {
          continue;
        }
      }
      return passes;
    }
    prepareActionEvent(event) {
      return Object.assign(event, { params: this.action.params });
    }
    invokeWithEvent(event) {
      const { target, currentTarget } = event;
      try {
        this.method.call(this.controller, event);
        this.context.logDebugActivity(this.methodName, { event, target, currentTarget, action: this.methodName });
      } catch (error2) {
        const { identifier, controller, element, index } = this;
        const detail = { identifier, controller, element, index, event };
        this.context.handleError(error2, `invoking action "${this.action}"`, detail);
      }
    }
    willBeInvokedByEvent(event) {
      const eventTarget = event.target;
      if (event instanceof KeyboardEvent && this.action.shouldIgnoreKeyboardEvent(event)) {
        return false;
      }
      if (event instanceof MouseEvent && this.action.shouldIgnoreMouseEvent(event)) {
        return false;
      }
      if (this.element === eventTarget) {
        return true;
      } else if (eventTarget instanceof Element && this.element.contains(eventTarget)) {
        return this.scope.containsElement(eventTarget);
      } else {
        return this.scope.containsElement(this.action.element);
      }
    }
    get controller() {
      return this.context.controller;
    }
    get methodName() {
      return this.action.methodName;
    }
    get element() {
      return this.scope.element;
    }
    get scope() {
      return this.context.scope;
    }
  };
  var ElementObserver = class {
    constructor(element, delegate) {
      this.mutationObserverInit = { attributes: true, childList: true, subtree: true };
      this.element = element;
      this.started = false;
      this.delegate = delegate;
      this.elements = /* @__PURE__ */ new Set();
      this.mutationObserver = new MutationObserver((mutations) => this.processMutations(mutations));
    }
    start() {
      if (!this.started) {
        this.started = true;
        this.mutationObserver.observe(this.element, this.mutationObserverInit);
        this.refresh();
      }
    }
    pause(callback) {
      if (this.started) {
        this.mutationObserver.disconnect();
        this.started = false;
      }
      callback();
      if (!this.started) {
        this.mutationObserver.observe(this.element, this.mutationObserverInit);
        this.started = true;
      }
    }
    stop() {
      if (this.started) {
        this.mutationObserver.takeRecords();
        this.mutationObserver.disconnect();
        this.started = false;
      }
    }
    refresh() {
      if (this.started) {
        const matches = new Set(this.matchElementsInTree());
        for (const element of Array.from(this.elements)) {
          if (!matches.has(element)) {
            this.removeElement(element);
          }
        }
        for (const element of Array.from(matches)) {
          this.addElement(element);
        }
      }
    }
    processMutations(mutations) {
      if (this.started) {
        for (const mutation of mutations) {
          this.processMutation(mutation);
        }
      }
    }
    processMutation(mutation) {
      if (mutation.type == "attributes") {
        this.processAttributeChange(mutation.target, mutation.attributeName);
      } else if (mutation.type == "childList") {
        this.processRemovedNodes(mutation.removedNodes);
        this.processAddedNodes(mutation.addedNodes);
      }
    }
    processAttributeChange(element, attributeName) {
      if (this.elements.has(element)) {
        if (this.delegate.elementAttributeChanged && this.matchElement(element)) {
          this.delegate.elementAttributeChanged(element, attributeName);
        } else {
          this.removeElement(element);
        }
      } else if (this.matchElement(element)) {
        this.addElement(element);
      }
    }
    processRemovedNodes(nodes) {
      for (const node of Array.from(nodes)) {
        const element = this.elementFromNode(node);
        if (element) {
          this.processTree(element, this.removeElement);
        }
      }
    }
    processAddedNodes(nodes) {
      for (const node of Array.from(nodes)) {
        const element = this.elementFromNode(node);
        if (element && this.elementIsActive(element)) {
          this.processTree(element, this.addElement);
        }
      }
    }
    matchElement(element) {
      return this.delegate.matchElement(element);
    }
    matchElementsInTree(tree = this.element) {
      return this.delegate.matchElementsInTree(tree);
    }
    processTree(tree, processor) {
      for (const element of this.matchElementsInTree(tree)) {
        processor.call(this, element);
      }
    }
    elementFromNode(node) {
      if (node.nodeType == Node.ELEMENT_NODE) {
        return node;
      }
    }
    elementIsActive(element) {
      if (element.isConnected != this.element.isConnected) {
        return false;
      } else {
        return this.element.contains(element);
      }
    }
    addElement(element) {
      if (!this.elements.has(element)) {
        if (this.elementIsActive(element)) {
          this.elements.add(element);
          if (this.delegate.elementMatched) {
            this.delegate.elementMatched(element);
          }
        }
      }
    }
    removeElement(element) {
      if (this.elements.has(element)) {
        this.elements.delete(element);
        if (this.delegate.elementUnmatched) {
          this.delegate.elementUnmatched(element);
        }
      }
    }
  };
  var AttributeObserver = class {
    constructor(element, attributeName, delegate) {
      this.attributeName = attributeName;
      this.delegate = delegate;
      this.elementObserver = new ElementObserver(element, this);
    }
    get element() {
      return this.elementObserver.element;
    }
    get selector() {
      return `[${this.attributeName}]`;
    }
    start() {
      this.elementObserver.start();
    }
    pause(callback) {
      this.elementObserver.pause(callback);
    }
    stop() {
      this.elementObserver.stop();
    }
    refresh() {
      this.elementObserver.refresh();
    }
    get started() {
      return this.elementObserver.started;
    }
    matchElement(element) {
      return element.hasAttribute(this.attributeName);
    }
    matchElementsInTree(tree) {
      const match = this.matchElement(tree) ? [tree] : [];
      const matches = Array.from(tree.querySelectorAll(this.selector));
      return match.concat(matches);
    }
    elementMatched(element) {
      if (this.delegate.elementMatchedAttribute) {
        this.delegate.elementMatchedAttribute(element, this.attributeName);
      }
    }
    elementUnmatched(element) {
      if (this.delegate.elementUnmatchedAttribute) {
        this.delegate.elementUnmatchedAttribute(element, this.attributeName);
      }
    }
    elementAttributeChanged(element, attributeName) {
      if (this.delegate.elementAttributeValueChanged && this.attributeName == attributeName) {
        this.delegate.elementAttributeValueChanged(element, attributeName);
      }
    }
  };
  function add(map, key, value) {
    fetch(map, key).add(value);
  }
  function del(map, key, value) {
    fetch(map, key).delete(value);
    prune(map, key);
  }
  function fetch(map, key) {
    let values = map.get(key);
    if (!values) {
      values = /* @__PURE__ */ new Set();
      map.set(key, values);
    }
    return values;
  }
  function prune(map, key) {
    const values = map.get(key);
    if (values != null && values.size == 0) {
      map.delete(key);
    }
  }
  var Multimap = class {
    constructor() {
      this.valuesByKey = /* @__PURE__ */ new Map();
    }
    get keys() {
      return Array.from(this.valuesByKey.keys());
    }
    get values() {
      const sets = Array.from(this.valuesByKey.values());
      return sets.reduce((values, set) => values.concat(Array.from(set)), []);
    }
    get size() {
      const sets = Array.from(this.valuesByKey.values());
      return sets.reduce((size, set) => size + set.size, 0);
    }
    add(key, value) {
      add(this.valuesByKey, key, value);
    }
    delete(key, value) {
      del(this.valuesByKey, key, value);
    }
    has(key, value) {
      const values = this.valuesByKey.get(key);
      return values != null && values.has(value);
    }
    hasKey(key) {
      return this.valuesByKey.has(key);
    }
    hasValue(value) {
      const sets = Array.from(this.valuesByKey.values());
      return sets.some((set) => set.has(value));
    }
    getValuesForKey(key) {
      const values = this.valuesByKey.get(key);
      return values ? Array.from(values) : [];
    }
    getKeysForValue(value) {
      return Array.from(this.valuesByKey).filter(([_key, values]) => values.has(value)).map(([key, _values]) => key);
    }
  };
  var SelectorObserver = class {
    constructor(element, selector, delegate, details) {
      this._selector = selector;
      this.details = details;
      this.elementObserver = new ElementObserver(element, this);
      this.delegate = delegate;
      this.matchesByElement = new Multimap();
    }
    get started() {
      return this.elementObserver.started;
    }
    get selector() {
      return this._selector;
    }
    set selector(selector) {
      this._selector = selector;
      this.refresh();
    }
    start() {
      this.elementObserver.start();
    }
    pause(callback) {
      this.elementObserver.pause(callback);
    }
    stop() {
      this.elementObserver.stop();
    }
    refresh() {
      this.elementObserver.refresh();
    }
    get element() {
      return this.elementObserver.element;
    }
    matchElement(element) {
      const { selector } = this;
      if (selector) {
        const matches = element.matches(selector);
        if (this.delegate.selectorMatchElement) {
          return matches && this.delegate.selectorMatchElement(element, this.details);
        }
        return matches;
      } else {
        return false;
      }
    }
    matchElementsInTree(tree) {
      const { selector } = this;
      if (selector) {
        const match = this.matchElement(tree) ? [tree] : [];
        const matches = Array.from(tree.querySelectorAll(selector)).filter((match2) => this.matchElement(match2));
        return match.concat(matches);
      } else {
        return [];
      }
    }
    elementMatched(element) {
      const { selector } = this;
      if (selector) {
        this.selectorMatched(element, selector);
      }
    }
    elementUnmatched(element) {
      const selectors = this.matchesByElement.getKeysForValue(element);
      for (const selector of selectors) {
        this.selectorUnmatched(element, selector);
      }
    }
    elementAttributeChanged(element, _attributeName) {
      const { selector } = this;
      if (selector) {
        const matches = this.matchElement(element);
        const matchedBefore = this.matchesByElement.has(selector, element);
        if (matches && !matchedBefore) {
          this.selectorMatched(element, selector);
        } else if (!matches && matchedBefore) {
          this.selectorUnmatched(element, selector);
        }
      }
    }
    selectorMatched(element, selector) {
      this.delegate.selectorMatched(element, selector, this.details);
      this.matchesByElement.add(selector, element);
    }
    selectorUnmatched(element, selector) {
      this.delegate.selectorUnmatched(element, selector, this.details);
      this.matchesByElement.delete(selector, element);
    }
  };
  var StringMapObserver = class {
    constructor(element, delegate) {
      this.element = element;
      this.delegate = delegate;
      this.started = false;
      this.stringMap = /* @__PURE__ */ new Map();
      this.mutationObserver = new MutationObserver((mutations) => this.processMutations(mutations));
    }
    start() {
      if (!this.started) {
        this.started = true;
        this.mutationObserver.observe(this.element, { attributes: true, attributeOldValue: true });
        this.refresh();
      }
    }
    stop() {
      if (this.started) {
        this.mutationObserver.takeRecords();
        this.mutationObserver.disconnect();
        this.started = false;
      }
    }
    refresh() {
      if (this.started) {
        for (const attributeName of this.knownAttributeNames) {
          this.refreshAttribute(attributeName, null);
        }
      }
    }
    processMutations(mutations) {
      if (this.started) {
        for (const mutation of mutations) {
          this.processMutation(mutation);
        }
      }
    }
    processMutation(mutation) {
      const attributeName = mutation.attributeName;
      if (attributeName) {
        this.refreshAttribute(attributeName, mutation.oldValue);
      }
    }
    refreshAttribute(attributeName, oldValue) {
      const key = this.delegate.getStringMapKeyForAttribute(attributeName);
      if (key != null) {
        if (!this.stringMap.has(attributeName)) {
          this.stringMapKeyAdded(key, attributeName);
        }
        const value = this.element.getAttribute(attributeName);
        if (this.stringMap.get(attributeName) != value) {
          this.stringMapValueChanged(value, key, oldValue);
        }
        if (value == null) {
          const oldValue2 = this.stringMap.get(attributeName);
          this.stringMap.delete(attributeName);
          if (oldValue2)
            this.stringMapKeyRemoved(key, attributeName, oldValue2);
        } else {
          this.stringMap.set(attributeName, value);
        }
      }
    }
    stringMapKeyAdded(key, attributeName) {
      if (this.delegate.stringMapKeyAdded) {
        this.delegate.stringMapKeyAdded(key, attributeName);
      }
    }
    stringMapValueChanged(value, key, oldValue) {
      if (this.delegate.stringMapValueChanged) {
        this.delegate.stringMapValueChanged(value, key, oldValue);
      }
    }
    stringMapKeyRemoved(key, attributeName, oldValue) {
      if (this.delegate.stringMapKeyRemoved) {
        this.delegate.stringMapKeyRemoved(key, attributeName, oldValue);
      }
    }
    get knownAttributeNames() {
      return Array.from(new Set(this.currentAttributeNames.concat(this.recordedAttributeNames)));
    }
    get currentAttributeNames() {
      return Array.from(this.element.attributes).map((attribute) => attribute.name);
    }
    get recordedAttributeNames() {
      return Array.from(this.stringMap.keys());
    }
  };
  var TokenListObserver = class {
    constructor(element, attributeName, delegate) {
      this.attributeObserver = new AttributeObserver(element, attributeName, this);
      this.delegate = delegate;
      this.tokensByElement = new Multimap();
    }
    get started() {
      return this.attributeObserver.started;
    }
    start() {
      this.attributeObserver.start();
    }
    pause(callback) {
      this.attributeObserver.pause(callback);
    }
    stop() {
      this.attributeObserver.stop();
    }
    refresh() {
      this.attributeObserver.refresh();
    }
    get element() {
      return this.attributeObserver.element;
    }
    get attributeName() {
      return this.attributeObserver.attributeName;
    }
    elementMatchedAttribute(element) {
      this.tokensMatched(this.readTokensForElement(element));
    }
    elementAttributeValueChanged(element) {
      const [unmatchedTokens, matchedTokens] = this.refreshTokensForElement(element);
      this.tokensUnmatched(unmatchedTokens);
      this.tokensMatched(matchedTokens);
    }
    elementUnmatchedAttribute(element) {
      this.tokensUnmatched(this.tokensByElement.getValuesForKey(element));
    }
    tokensMatched(tokens) {
      tokens.forEach((token) => this.tokenMatched(token));
    }
    tokensUnmatched(tokens) {
      tokens.forEach((token) => this.tokenUnmatched(token));
    }
    tokenMatched(token) {
      this.delegate.tokenMatched(token);
      this.tokensByElement.add(token.element, token);
    }
    tokenUnmatched(token) {
      this.delegate.tokenUnmatched(token);
      this.tokensByElement.delete(token.element, token);
    }
    refreshTokensForElement(element) {
      const previousTokens = this.tokensByElement.getValuesForKey(element);
      const currentTokens = this.readTokensForElement(element);
      const firstDifferingIndex = zip(previousTokens, currentTokens).findIndex(([previousToken, currentToken]) => !tokensAreEqual(previousToken, currentToken));
      if (firstDifferingIndex == -1) {
        return [[], []];
      } else {
        return [previousTokens.slice(firstDifferingIndex), currentTokens.slice(firstDifferingIndex)];
      }
    }
    readTokensForElement(element) {
      const attributeName = this.attributeName;
      const tokenString = element.getAttribute(attributeName) || "";
      return parseTokenString(tokenString, element, attributeName);
    }
  };
  function parseTokenString(tokenString, element, attributeName) {
    return tokenString.trim().split(/\s+/).filter((content) => content.length).map((content, index) => ({ element, attributeName, content, index }));
  }
  function zip(left, right) {
    const length = Math.max(left.length, right.length);
    return Array.from({ length }, (_, index) => [left[index], right[index]]);
  }
  function tokensAreEqual(left, right) {
    return left && right && left.index == right.index && left.content == right.content;
  }
  var ValueListObserver = class {
    constructor(element, attributeName, delegate) {
      this.tokenListObserver = new TokenListObserver(element, attributeName, this);
      this.delegate = delegate;
      this.parseResultsByToken = /* @__PURE__ */ new WeakMap();
      this.valuesByTokenByElement = /* @__PURE__ */ new WeakMap();
    }
    get started() {
      return this.tokenListObserver.started;
    }
    start() {
      this.tokenListObserver.start();
    }
    stop() {
      this.tokenListObserver.stop();
    }
    refresh() {
      this.tokenListObserver.refresh();
    }
    get element() {
      return this.tokenListObserver.element;
    }
    get attributeName() {
      return this.tokenListObserver.attributeName;
    }
    tokenMatched(token) {
      const { element } = token;
      const { value } = this.fetchParseResultForToken(token);
      if (value) {
        this.fetchValuesByTokenForElement(element).set(token, value);
        this.delegate.elementMatchedValue(element, value);
      }
    }
    tokenUnmatched(token) {
      const { element } = token;
      const { value } = this.fetchParseResultForToken(token);
      if (value) {
        this.fetchValuesByTokenForElement(element).delete(token);
        this.delegate.elementUnmatchedValue(element, value);
      }
    }
    fetchParseResultForToken(token) {
      let parseResult = this.parseResultsByToken.get(token);
      if (!parseResult) {
        parseResult = this.parseToken(token);
        this.parseResultsByToken.set(token, parseResult);
      }
      return parseResult;
    }
    fetchValuesByTokenForElement(element) {
      let valuesByToken = this.valuesByTokenByElement.get(element);
      if (!valuesByToken) {
        valuesByToken = /* @__PURE__ */ new Map();
        this.valuesByTokenByElement.set(element, valuesByToken);
      }
      return valuesByToken;
    }
    parseToken(token) {
      try {
        const value = this.delegate.parseValueForToken(token);
        return { value };
      } catch (error2) {
        return { error: error2 };
      }
    }
  };
  var BindingObserver = class {
    constructor(context, delegate) {
      this.context = context;
      this.delegate = delegate;
      this.bindingsByAction = /* @__PURE__ */ new Map();
    }
    start() {
      if (!this.valueListObserver) {
        this.valueListObserver = new ValueListObserver(this.element, this.actionAttribute, this);
        this.valueListObserver.start();
      }
    }
    stop() {
      if (this.valueListObserver) {
        this.valueListObserver.stop();
        delete this.valueListObserver;
        this.disconnectAllActions();
      }
    }
    get element() {
      return this.context.element;
    }
    get identifier() {
      return this.context.identifier;
    }
    get actionAttribute() {
      return this.schema.actionAttribute;
    }
    get schema() {
      return this.context.schema;
    }
    get bindings() {
      return Array.from(this.bindingsByAction.values());
    }
    connectAction(action) {
      const binding = new Binding(this.context, action);
      this.bindingsByAction.set(action, binding);
      this.delegate.bindingConnected(binding);
    }
    disconnectAction(action) {
      const binding = this.bindingsByAction.get(action);
      if (binding) {
        this.bindingsByAction.delete(action);
        this.delegate.bindingDisconnected(binding);
      }
    }
    disconnectAllActions() {
      this.bindings.forEach((binding) => this.delegate.bindingDisconnected(binding, true));
      this.bindingsByAction.clear();
    }
    parseValueForToken(token) {
      const action = Action.forToken(token, this.schema);
      if (action.identifier == this.identifier) {
        return action;
      }
    }
    elementMatchedValue(element, action) {
      this.connectAction(action);
    }
    elementUnmatchedValue(element, action) {
      this.disconnectAction(action);
    }
  };
  var ValueObserver = class {
    constructor(context, receiver) {
      this.context = context;
      this.receiver = receiver;
      this.stringMapObserver = new StringMapObserver(this.element, this);
      this.valueDescriptorMap = this.controller.valueDescriptorMap;
    }
    start() {
      this.stringMapObserver.start();
      this.invokeChangedCallbacksForDefaultValues();
    }
    stop() {
      this.stringMapObserver.stop();
    }
    get element() {
      return this.context.element;
    }
    get controller() {
      return this.context.controller;
    }
    getStringMapKeyForAttribute(attributeName) {
      if (attributeName in this.valueDescriptorMap) {
        return this.valueDescriptorMap[attributeName].name;
      }
    }
    stringMapKeyAdded(key, attributeName) {
      const descriptor = this.valueDescriptorMap[attributeName];
      if (!this.hasValue(key)) {
        this.invokeChangedCallback(key, descriptor.writer(this.receiver[key]), descriptor.writer(descriptor.defaultValue));
      }
    }
    stringMapValueChanged(value, name, oldValue) {
      const descriptor = this.valueDescriptorNameMap[name];
      if (value === null)
        return;
      if (oldValue === null) {
        oldValue = descriptor.writer(descriptor.defaultValue);
      }
      this.invokeChangedCallback(name, value, oldValue);
    }
    stringMapKeyRemoved(key, attributeName, oldValue) {
      const descriptor = this.valueDescriptorNameMap[key];
      if (this.hasValue(key)) {
        this.invokeChangedCallback(key, descriptor.writer(this.receiver[key]), oldValue);
      } else {
        this.invokeChangedCallback(key, descriptor.writer(descriptor.defaultValue), oldValue);
      }
    }
    invokeChangedCallbacksForDefaultValues() {
      for (const { key, name, defaultValue, writer } of this.valueDescriptors) {
        if (defaultValue != void 0 && !this.controller.data.has(key)) {
          this.invokeChangedCallback(name, writer(defaultValue), void 0);
        }
      }
    }
    invokeChangedCallback(name, rawValue, rawOldValue) {
      const changedMethodName = `${name}Changed`;
      const changedMethod = this.receiver[changedMethodName];
      if (typeof changedMethod == "function") {
        const descriptor = this.valueDescriptorNameMap[name];
        try {
          const value = descriptor.reader(rawValue);
          let oldValue = rawOldValue;
          if (rawOldValue) {
            oldValue = descriptor.reader(rawOldValue);
          }
          changedMethod.call(this.receiver, value, oldValue);
        } catch (error2) {
          if (error2 instanceof TypeError) {
            error2.message = `Stimulus Value "${this.context.identifier}.${descriptor.name}" - ${error2.message}`;
          }
          throw error2;
        }
      }
    }
    get valueDescriptors() {
      const { valueDescriptorMap } = this;
      return Object.keys(valueDescriptorMap).map((key) => valueDescriptorMap[key]);
    }
    get valueDescriptorNameMap() {
      const descriptors = {};
      Object.keys(this.valueDescriptorMap).forEach((key) => {
        const descriptor = this.valueDescriptorMap[key];
        descriptors[descriptor.name] = descriptor;
      });
      return descriptors;
    }
    hasValue(attributeName) {
      const descriptor = this.valueDescriptorNameMap[attributeName];
      const hasMethodName = `has${capitalize(descriptor.name)}`;
      return this.receiver[hasMethodName];
    }
  };
  var TargetObserver = class {
    constructor(context, delegate) {
      this.context = context;
      this.delegate = delegate;
      this.targetsByName = new Multimap();
    }
    start() {
      if (!this.tokenListObserver) {
        this.tokenListObserver = new TokenListObserver(this.element, this.attributeName, this);
        this.tokenListObserver.start();
      }
    }
    stop() {
      if (this.tokenListObserver) {
        this.disconnectAllTargets();
        this.tokenListObserver.stop();
        delete this.tokenListObserver;
      }
    }
    tokenMatched({ element, content: name }) {
      if (this.scope.containsElement(element)) {
        this.connectTarget(element, name);
      }
    }
    tokenUnmatched({ element, content: name }) {
      this.disconnectTarget(element, name);
    }
    connectTarget(element, name) {
      var _a;
      if (!this.targetsByName.has(name, element)) {
        this.targetsByName.add(name, element);
        (_a = this.tokenListObserver) === null || _a === void 0 ? void 0 : _a.pause(() => this.delegate.targetConnected(element, name));
      }
    }
    disconnectTarget(element, name) {
      var _a;
      if (this.targetsByName.has(name, element)) {
        this.targetsByName.delete(name, element);
        (_a = this.tokenListObserver) === null || _a === void 0 ? void 0 : _a.pause(() => this.delegate.targetDisconnected(element, name));
      }
    }
    disconnectAllTargets() {
      for (const name of this.targetsByName.keys) {
        for (const element of this.targetsByName.getValuesForKey(name)) {
          this.disconnectTarget(element, name);
        }
      }
    }
    get attributeName() {
      return `data-${this.context.identifier}-target`;
    }
    get element() {
      return this.context.element;
    }
    get scope() {
      return this.context.scope;
    }
  };
  function readInheritableStaticArrayValues(constructor, propertyName) {
    const ancestors = getAncestorsForConstructor(constructor);
    return Array.from(ancestors.reduce((values, constructor2) => {
      getOwnStaticArrayValues(constructor2, propertyName).forEach((name) => values.add(name));
      return values;
    }, /* @__PURE__ */ new Set()));
  }
  function readInheritableStaticObjectPairs(constructor, propertyName) {
    const ancestors = getAncestorsForConstructor(constructor);
    return ancestors.reduce((pairs, constructor2) => {
      pairs.push(...getOwnStaticObjectPairs(constructor2, propertyName));
      return pairs;
    }, []);
  }
  function getAncestorsForConstructor(constructor) {
    const ancestors = [];
    while (constructor) {
      ancestors.push(constructor);
      constructor = Object.getPrototypeOf(constructor);
    }
    return ancestors.reverse();
  }
  function getOwnStaticArrayValues(constructor, propertyName) {
    const definition = constructor[propertyName];
    return Array.isArray(definition) ? definition : [];
  }
  function getOwnStaticObjectPairs(constructor, propertyName) {
    const definition = constructor[propertyName];
    return definition ? Object.keys(definition).map((key) => [key, definition[key]]) : [];
  }
  var OutletObserver = class {
    constructor(context, delegate) {
      this.started = false;
      this.context = context;
      this.delegate = delegate;
      this.outletsByName = new Multimap();
      this.outletElementsByName = new Multimap();
      this.selectorObserverMap = /* @__PURE__ */ new Map();
      this.attributeObserverMap = /* @__PURE__ */ new Map();
    }
    start() {
      if (!this.started) {
        this.outletDefinitions.forEach((outletName) => {
          this.setupSelectorObserverForOutlet(outletName);
          this.setupAttributeObserverForOutlet(outletName);
        });
        this.started = true;
        this.dependentContexts.forEach((context) => context.refresh());
      }
    }
    refresh() {
      this.selectorObserverMap.forEach((observer) => observer.refresh());
      this.attributeObserverMap.forEach((observer) => observer.refresh());
    }
    stop() {
      if (this.started) {
        this.started = false;
        this.disconnectAllOutlets();
        this.stopSelectorObservers();
        this.stopAttributeObservers();
      }
    }
    stopSelectorObservers() {
      if (this.selectorObserverMap.size > 0) {
        this.selectorObserverMap.forEach((observer) => observer.stop());
        this.selectorObserverMap.clear();
      }
    }
    stopAttributeObservers() {
      if (this.attributeObserverMap.size > 0) {
        this.attributeObserverMap.forEach((observer) => observer.stop());
        this.attributeObserverMap.clear();
      }
    }
    selectorMatched(element, _selector, { outletName }) {
      const outlet = this.getOutlet(element, outletName);
      if (outlet) {
        this.connectOutlet(outlet, element, outletName);
      }
    }
    selectorUnmatched(element, _selector, { outletName }) {
      const outlet = this.getOutletFromMap(element, outletName);
      if (outlet) {
        this.disconnectOutlet(outlet, element, outletName);
      }
    }
    selectorMatchElement(element, { outletName }) {
      const selector = this.selector(outletName);
      const hasOutlet = this.hasOutlet(element, outletName);
      const hasOutletController = element.matches(`[${this.schema.controllerAttribute}~=${outletName}]`);
      if (selector) {
        return hasOutlet && hasOutletController && element.matches(selector);
      } else {
        return false;
      }
    }
    elementMatchedAttribute(_element, attributeName) {
      const outletName = this.getOutletNameFromOutletAttributeName(attributeName);
      if (outletName) {
        this.updateSelectorObserverForOutlet(outletName);
      }
    }
    elementAttributeValueChanged(_element, attributeName) {
      const outletName = this.getOutletNameFromOutletAttributeName(attributeName);
      if (outletName) {
        this.updateSelectorObserverForOutlet(outletName);
      }
    }
    elementUnmatchedAttribute(_element, attributeName) {
      const outletName = this.getOutletNameFromOutletAttributeName(attributeName);
      if (outletName) {
        this.updateSelectorObserverForOutlet(outletName);
      }
    }
    connectOutlet(outlet, element, outletName) {
      var _a;
      if (!this.outletElementsByName.has(outletName, element)) {
        this.outletsByName.add(outletName, outlet);
        this.outletElementsByName.add(outletName, element);
        (_a = this.selectorObserverMap.get(outletName)) === null || _a === void 0 ? void 0 : _a.pause(() => this.delegate.outletConnected(outlet, element, outletName));
      }
    }
    disconnectOutlet(outlet, element, outletName) {
      var _a;
      if (this.outletElementsByName.has(outletName, element)) {
        this.outletsByName.delete(outletName, outlet);
        this.outletElementsByName.delete(outletName, element);
        (_a = this.selectorObserverMap.get(outletName)) === null || _a === void 0 ? void 0 : _a.pause(() => this.delegate.outletDisconnected(outlet, element, outletName));
      }
    }
    disconnectAllOutlets() {
      for (const outletName of this.outletElementsByName.keys) {
        for (const element of this.outletElementsByName.getValuesForKey(outletName)) {
          for (const outlet of this.outletsByName.getValuesForKey(outletName)) {
            this.disconnectOutlet(outlet, element, outletName);
          }
        }
      }
    }
    updateSelectorObserverForOutlet(outletName) {
      const observer = this.selectorObserverMap.get(outletName);
      if (observer) {
        observer.selector = this.selector(outletName);
      }
    }
    setupSelectorObserverForOutlet(outletName) {
      const selector = this.selector(outletName);
      const selectorObserver = new SelectorObserver(document.body, selector, this, { outletName });
      this.selectorObserverMap.set(outletName, selectorObserver);
      selectorObserver.start();
    }
    setupAttributeObserverForOutlet(outletName) {
      const attributeName = this.attributeNameForOutletName(outletName);
      const attributeObserver = new AttributeObserver(this.scope.element, attributeName, this);
      this.attributeObserverMap.set(outletName, attributeObserver);
      attributeObserver.start();
    }
    selector(outletName) {
      return this.scope.outlets.getSelectorForOutletName(outletName);
    }
    attributeNameForOutletName(outletName) {
      return this.scope.schema.outletAttributeForScope(this.identifier, outletName);
    }
    getOutletNameFromOutletAttributeName(attributeName) {
      return this.outletDefinitions.find((outletName) => this.attributeNameForOutletName(outletName) === attributeName);
    }
    get outletDependencies() {
      const dependencies = new Multimap();
      this.router.modules.forEach((module) => {
        const constructor = module.definition.controllerConstructor;
        const outlets = readInheritableStaticArrayValues(constructor, "outlets");
        outlets.forEach((outlet) => dependencies.add(outlet, module.identifier));
      });
      return dependencies;
    }
    get outletDefinitions() {
      return this.outletDependencies.getKeysForValue(this.identifier);
    }
    get dependentControllerIdentifiers() {
      return this.outletDependencies.getValuesForKey(this.identifier);
    }
    get dependentContexts() {
      const identifiers = this.dependentControllerIdentifiers;
      return this.router.contexts.filter((context) => identifiers.includes(context.identifier));
    }
    hasOutlet(element, outletName) {
      return !!this.getOutlet(element, outletName) || !!this.getOutletFromMap(element, outletName);
    }
    getOutlet(element, outletName) {
      return this.application.getControllerForElementAndIdentifier(element, outletName);
    }
    getOutletFromMap(element, outletName) {
      return this.outletsByName.getValuesForKey(outletName).find((outlet) => outlet.element === element);
    }
    get scope() {
      return this.context.scope;
    }
    get schema() {
      return this.context.schema;
    }
    get identifier() {
      return this.context.identifier;
    }
    get application() {
      return this.context.application;
    }
    get router() {
      return this.application.router;
    }
  };
  var Context = class {
    constructor(module, scope) {
      this.logDebugActivity = (functionName, detail = {}) => {
        const { identifier, controller, element } = this;
        detail = Object.assign({ identifier, controller, element }, detail);
        this.application.logDebugActivity(this.identifier, functionName, detail);
      };
      this.module = module;
      this.scope = scope;
      this.controller = new module.controllerConstructor(this);
      this.bindingObserver = new BindingObserver(this, this.dispatcher);
      this.valueObserver = new ValueObserver(this, this.controller);
      this.targetObserver = new TargetObserver(this, this);
      this.outletObserver = new OutletObserver(this, this);
      try {
        this.controller.initialize();
        this.logDebugActivity("initialize");
      } catch (error2) {
        this.handleError(error2, "initializing controller");
      }
    }
    connect() {
      this.bindingObserver.start();
      this.valueObserver.start();
      this.targetObserver.start();
      this.outletObserver.start();
      try {
        this.controller.connect();
        this.logDebugActivity("connect");
      } catch (error2) {
        this.handleError(error2, "connecting controller");
      }
    }
    refresh() {
      this.outletObserver.refresh();
    }
    disconnect() {
      try {
        this.controller.disconnect();
        this.logDebugActivity("disconnect");
      } catch (error2) {
        this.handleError(error2, "disconnecting controller");
      }
      this.outletObserver.stop();
      this.targetObserver.stop();
      this.valueObserver.stop();
      this.bindingObserver.stop();
    }
    get application() {
      return this.module.application;
    }
    get identifier() {
      return this.module.identifier;
    }
    get schema() {
      return this.application.schema;
    }
    get dispatcher() {
      return this.application.dispatcher;
    }
    get element() {
      return this.scope.element;
    }
    get parentElement() {
      return this.element.parentElement;
    }
    handleError(error2, message, detail = {}) {
      const { identifier, controller, element } = this;
      detail = Object.assign({ identifier, controller, element }, detail);
      this.application.handleError(error2, `Error ${message}`, detail);
    }
    targetConnected(element, name) {
      this.invokeControllerMethod(`${name}TargetConnected`, element);
    }
    targetDisconnected(element, name) {
      this.invokeControllerMethod(`${name}TargetDisconnected`, element);
    }
    outletConnected(outlet, element, name) {
      this.invokeControllerMethod(`${namespaceCamelize(name)}OutletConnected`, outlet, element);
    }
    outletDisconnected(outlet, element, name) {
      this.invokeControllerMethod(`${namespaceCamelize(name)}OutletDisconnected`, outlet, element);
    }
    invokeControllerMethod(methodName, ...args) {
      const controller = this.controller;
      if (typeof controller[methodName] == "function") {
        controller[methodName](...args);
      }
    }
  };
  function bless(constructor) {
    return shadow(constructor, getBlessedProperties(constructor));
  }
  function shadow(constructor, properties) {
    const shadowConstructor = extend(constructor);
    const shadowProperties = getShadowProperties(constructor.prototype, properties);
    Object.defineProperties(shadowConstructor.prototype, shadowProperties);
    return shadowConstructor;
  }
  function getBlessedProperties(constructor) {
    const blessings = readInheritableStaticArrayValues(constructor, "blessings");
    return blessings.reduce((blessedProperties, blessing) => {
      const properties = blessing(constructor);
      for (const key in properties) {
        const descriptor = blessedProperties[key] || {};
        blessedProperties[key] = Object.assign(descriptor, properties[key]);
      }
      return blessedProperties;
    }, {});
  }
  function getShadowProperties(prototype, properties) {
    return getOwnKeys(properties).reduce((shadowProperties, key) => {
      const descriptor = getShadowedDescriptor(prototype, properties, key);
      if (descriptor) {
        Object.assign(shadowProperties, { [key]: descriptor });
      }
      return shadowProperties;
    }, {});
  }
  function getShadowedDescriptor(prototype, properties, key) {
    const shadowingDescriptor = Object.getOwnPropertyDescriptor(prototype, key);
    const shadowedByValue = shadowingDescriptor && "value" in shadowingDescriptor;
    if (!shadowedByValue) {
      const descriptor = Object.getOwnPropertyDescriptor(properties, key).value;
      if (shadowingDescriptor) {
        descriptor.get = shadowingDescriptor.get || descriptor.get;
        descriptor.set = shadowingDescriptor.set || descriptor.set;
      }
      return descriptor;
    }
  }
  var getOwnKeys = (() => {
    if (typeof Object.getOwnPropertySymbols == "function") {
      return (object) => [...Object.getOwnPropertyNames(object), ...Object.getOwnPropertySymbols(object)];
    } else {
      return Object.getOwnPropertyNames;
    }
  })();
  var extend = (() => {
    function extendWithReflect(constructor) {
      function extended() {
        return Reflect.construct(constructor, arguments, new.target);
      }
      extended.prototype = Object.create(constructor.prototype, {
        constructor: { value: extended }
      });
      Reflect.setPrototypeOf(extended, constructor);
      return extended;
    }
    function testReflectExtension() {
      const a = function() {
        this.a.call(this);
      };
      const b = extendWithReflect(a);
      b.prototype.a = function() {
      };
      return new b();
    }
    try {
      testReflectExtension();
      return extendWithReflect;
    } catch (error2) {
      return (constructor) => class extended extends constructor {
      };
    }
  })();
  function blessDefinition(definition) {
    return {
      identifier: definition.identifier,
      controllerConstructor: bless(definition.controllerConstructor)
    };
  }
  var Module = class {
    constructor(application, definition) {
      this.application = application;
      this.definition = blessDefinition(definition);
      this.contextsByScope = /* @__PURE__ */ new WeakMap();
      this.connectedContexts = /* @__PURE__ */ new Set();
    }
    get identifier() {
      return this.definition.identifier;
    }
    get controllerConstructor() {
      return this.definition.controllerConstructor;
    }
    get contexts() {
      return Array.from(this.connectedContexts);
    }
    connectContextForScope(scope) {
      const context = this.fetchContextForScope(scope);
      this.connectedContexts.add(context);
      context.connect();
    }
    disconnectContextForScope(scope) {
      const context = this.contextsByScope.get(scope);
      if (context) {
        this.connectedContexts.delete(context);
        context.disconnect();
      }
    }
    fetchContextForScope(scope) {
      let context = this.contextsByScope.get(scope);
      if (!context) {
        context = new Context(this, scope);
        this.contextsByScope.set(scope, context);
      }
      return context;
    }
  };
  var ClassMap = class {
    constructor(scope) {
      this.scope = scope;
    }
    has(name) {
      return this.data.has(this.getDataKey(name));
    }
    get(name) {
      return this.getAll(name)[0];
    }
    getAll(name) {
      const tokenString = this.data.get(this.getDataKey(name)) || "";
      return tokenize(tokenString);
    }
    getAttributeName(name) {
      return this.data.getAttributeNameForKey(this.getDataKey(name));
    }
    getDataKey(name) {
      return `${name}-class`;
    }
    get data() {
      return this.scope.data;
    }
  };
  var DataMap = class {
    constructor(scope) {
      this.scope = scope;
    }
    get element() {
      return this.scope.element;
    }
    get identifier() {
      return this.scope.identifier;
    }
    get(key) {
      const name = this.getAttributeNameForKey(key);
      return this.element.getAttribute(name);
    }
    set(key, value) {
      const name = this.getAttributeNameForKey(key);
      this.element.setAttribute(name, value);
      return this.get(key);
    }
    has(key) {
      const name = this.getAttributeNameForKey(key);
      return this.element.hasAttribute(name);
    }
    delete(key) {
      if (this.has(key)) {
        const name = this.getAttributeNameForKey(key);
        this.element.removeAttribute(name);
        return true;
      } else {
        return false;
      }
    }
    getAttributeNameForKey(key) {
      return `data-${this.identifier}-${dasherize(key)}`;
    }
  };
  var Guide = class {
    constructor(logger) {
      this.warnedKeysByObject = /* @__PURE__ */ new WeakMap();
      this.logger = logger;
    }
    warn(object, key, message) {
      let warnedKeys = this.warnedKeysByObject.get(object);
      if (!warnedKeys) {
        warnedKeys = /* @__PURE__ */ new Set();
        this.warnedKeysByObject.set(object, warnedKeys);
      }
      if (!warnedKeys.has(key)) {
        warnedKeys.add(key);
        this.logger.warn(message, object);
      }
    }
  };
  function attributeValueContainsToken(attributeName, token) {
    return `[${attributeName}~="${token}"]`;
  }
  var TargetSet = class {
    constructor(scope) {
      this.scope = scope;
    }
    get element() {
      return this.scope.element;
    }
    get identifier() {
      return this.scope.identifier;
    }
    get schema() {
      return this.scope.schema;
    }
    has(targetName) {
      return this.find(targetName) != null;
    }
    find(...targetNames) {
      return targetNames.reduce((target, targetName) => target || this.findTarget(targetName) || this.findLegacyTarget(targetName), void 0);
    }
    findAll(...targetNames) {
      return targetNames.reduce((targets, targetName) => [
        ...targets,
        ...this.findAllTargets(targetName),
        ...this.findAllLegacyTargets(targetName)
      ], []);
    }
    findTarget(targetName) {
      const selector = this.getSelectorForTargetName(targetName);
      return this.scope.findElement(selector);
    }
    findAllTargets(targetName) {
      const selector = this.getSelectorForTargetName(targetName);
      return this.scope.findAllElements(selector);
    }
    getSelectorForTargetName(targetName) {
      const attributeName = this.schema.targetAttributeForScope(this.identifier);
      return attributeValueContainsToken(attributeName, targetName);
    }
    findLegacyTarget(targetName) {
      const selector = this.getLegacySelectorForTargetName(targetName);
      return this.deprecate(this.scope.findElement(selector), targetName);
    }
    findAllLegacyTargets(targetName) {
      const selector = this.getLegacySelectorForTargetName(targetName);
      return this.scope.findAllElements(selector).map((element) => this.deprecate(element, targetName));
    }
    getLegacySelectorForTargetName(targetName) {
      const targetDescriptor = `${this.identifier}.${targetName}`;
      return attributeValueContainsToken(this.schema.targetAttribute, targetDescriptor);
    }
    deprecate(element, targetName) {
      if (element) {
        const { identifier } = this;
        const attributeName = this.schema.targetAttribute;
        const revisedAttributeName = this.schema.targetAttributeForScope(identifier);
        this.guide.warn(element, `target:${targetName}`, `Please replace ${attributeName}="${identifier}.${targetName}" with ${revisedAttributeName}="${targetName}". The ${attributeName} attribute is deprecated and will be removed in a future version of Stimulus.`);
      }
      return element;
    }
    get guide() {
      return this.scope.guide;
    }
  };
  var OutletSet = class {
    constructor(scope, controllerElement) {
      this.scope = scope;
      this.controllerElement = controllerElement;
    }
    get element() {
      return this.scope.element;
    }
    get identifier() {
      return this.scope.identifier;
    }
    get schema() {
      return this.scope.schema;
    }
    has(outletName) {
      return this.find(outletName) != null;
    }
    find(...outletNames) {
      return outletNames.reduce((outlet, outletName) => outlet || this.findOutlet(outletName), void 0);
    }
    findAll(...outletNames) {
      return outletNames.reduce((outlets, outletName) => [...outlets, ...this.findAllOutlets(outletName)], []);
    }
    getSelectorForOutletName(outletName) {
      const attributeName = this.schema.outletAttributeForScope(this.identifier, outletName);
      return this.controllerElement.getAttribute(attributeName);
    }
    findOutlet(outletName) {
      const selector = this.getSelectorForOutletName(outletName);
      if (selector)
        return this.findElement(selector, outletName);
    }
    findAllOutlets(outletName) {
      const selector = this.getSelectorForOutletName(outletName);
      return selector ? this.findAllElements(selector, outletName) : [];
    }
    findElement(selector, outletName) {
      const elements = this.scope.queryElements(selector);
      return elements.filter((element) => this.matchesElement(element, selector, outletName))[0];
    }
    findAllElements(selector, outletName) {
      const elements = this.scope.queryElements(selector);
      return elements.filter((element) => this.matchesElement(element, selector, outletName));
    }
    matchesElement(element, selector, outletName) {
      const controllerAttribute = element.getAttribute(this.scope.schema.controllerAttribute) || "";
      return element.matches(selector) && controllerAttribute.split(" ").includes(outletName);
    }
  };
  var Scope = class _Scope {
    constructor(schema, element, identifier, logger) {
      this.targets = new TargetSet(this);
      this.classes = new ClassMap(this);
      this.data = new DataMap(this);
      this.containsElement = (element2) => {
        return element2.closest(this.controllerSelector) === this.element;
      };
      this.schema = schema;
      this.element = element;
      this.identifier = identifier;
      this.guide = new Guide(logger);
      this.outlets = new OutletSet(this.documentScope, element);
    }
    findElement(selector) {
      return this.element.matches(selector) ? this.element : this.queryElements(selector).find(this.containsElement);
    }
    findAllElements(selector) {
      return [
        ...this.element.matches(selector) ? [this.element] : [],
        ...this.queryElements(selector).filter(this.containsElement)
      ];
    }
    queryElements(selector) {
      return Array.from(this.element.querySelectorAll(selector));
    }
    get controllerSelector() {
      return attributeValueContainsToken(this.schema.controllerAttribute, this.identifier);
    }
    get isDocumentScope() {
      return this.element === document.documentElement;
    }
    get documentScope() {
      return this.isDocumentScope ? this : new _Scope(this.schema, document.documentElement, this.identifier, this.guide.logger);
    }
  };
  var ScopeObserver = class {
    constructor(element, schema, delegate) {
      this.element = element;
      this.schema = schema;
      this.delegate = delegate;
      this.valueListObserver = new ValueListObserver(this.element, this.controllerAttribute, this);
      this.scopesByIdentifierByElement = /* @__PURE__ */ new WeakMap();
      this.scopeReferenceCounts = /* @__PURE__ */ new WeakMap();
    }
    start() {
      this.valueListObserver.start();
    }
    stop() {
      this.valueListObserver.stop();
    }
    get controllerAttribute() {
      return this.schema.controllerAttribute;
    }
    parseValueForToken(token) {
      const { element, content: identifier } = token;
      return this.parseValueForElementAndIdentifier(element, identifier);
    }
    parseValueForElementAndIdentifier(element, identifier) {
      const scopesByIdentifier = this.fetchScopesByIdentifierForElement(element);
      let scope = scopesByIdentifier.get(identifier);
      if (!scope) {
        scope = this.delegate.createScopeForElementAndIdentifier(element, identifier);
        scopesByIdentifier.set(identifier, scope);
      }
      return scope;
    }
    elementMatchedValue(element, value) {
      const referenceCount = (this.scopeReferenceCounts.get(value) || 0) + 1;
      this.scopeReferenceCounts.set(value, referenceCount);
      if (referenceCount == 1) {
        this.delegate.scopeConnected(value);
      }
    }
    elementUnmatchedValue(element, value) {
      const referenceCount = this.scopeReferenceCounts.get(value);
      if (referenceCount) {
        this.scopeReferenceCounts.set(value, referenceCount - 1);
        if (referenceCount == 1) {
          this.delegate.scopeDisconnected(value);
        }
      }
    }
    fetchScopesByIdentifierForElement(element) {
      let scopesByIdentifier = this.scopesByIdentifierByElement.get(element);
      if (!scopesByIdentifier) {
        scopesByIdentifier = /* @__PURE__ */ new Map();
        this.scopesByIdentifierByElement.set(element, scopesByIdentifier);
      }
      return scopesByIdentifier;
    }
  };
  var Router = class {
    constructor(application) {
      this.application = application;
      this.scopeObserver = new ScopeObserver(this.element, this.schema, this);
      this.scopesByIdentifier = new Multimap();
      this.modulesByIdentifier = /* @__PURE__ */ new Map();
    }
    get element() {
      return this.application.element;
    }
    get schema() {
      return this.application.schema;
    }
    get logger() {
      return this.application.logger;
    }
    get controllerAttribute() {
      return this.schema.controllerAttribute;
    }
    get modules() {
      return Array.from(this.modulesByIdentifier.values());
    }
    get contexts() {
      return this.modules.reduce((contexts, module) => contexts.concat(module.contexts), []);
    }
    start() {
      this.scopeObserver.start();
    }
    stop() {
      this.scopeObserver.stop();
    }
    loadDefinition(definition) {
      this.unloadIdentifier(definition.identifier);
      const module = new Module(this.application, definition);
      this.connectModule(module);
      const afterLoad = definition.controllerConstructor.afterLoad;
      if (afterLoad) {
        afterLoad.call(definition.controllerConstructor, definition.identifier, this.application);
      }
    }
    unloadIdentifier(identifier) {
      const module = this.modulesByIdentifier.get(identifier);
      if (module) {
        this.disconnectModule(module);
      }
    }
    getContextForElementAndIdentifier(element, identifier) {
      const module = this.modulesByIdentifier.get(identifier);
      if (module) {
        return module.contexts.find((context) => context.element == element);
      }
    }
    proposeToConnectScopeForElementAndIdentifier(element, identifier) {
      const scope = this.scopeObserver.parseValueForElementAndIdentifier(element, identifier);
      if (scope) {
        this.scopeObserver.elementMatchedValue(scope.element, scope);
      } else {
        console.error(`Couldn't find or create scope for identifier: "${identifier}" and element:`, element);
      }
    }
    handleError(error2, message, detail) {
      this.application.handleError(error2, message, detail);
    }
    createScopeForElementAndIdentifier(element, identifier) {
      return new Scope(this.schema, element, identifier, this.logger);
    }
    scopeConnected(scope) {
      this.scopesByIdentifier.add(scope.identifier, scope);
      const module = this.modulesByIdentifier.get(scope.identifier);
      if (module) {
        module.connectContextForScope(scope);
      }
    }
    scopeDisconnected(scope) {
      this.scopesByIdentifier.delete(scope.identifier, scope);
      const module = this.modulesByIdentifier.get(scope.identifier);
      if (module) {
        module.disconnectContextForScope(scope);
      }
    }
    connectModule(module) {
      this.modulesByIdentifier.set(module.identifier, module);
      const scopes = this.scopesByIdentifier.getValuesForKey(module.identifier);
      scopes.forEach((scope) => module.connectContextForScope(scope));
    }
    disconnectModule(module) {
      this.modulesByIdentifier.delete(module.identifier);
      const scopes = this.scopesByIdentifier.getValuesForKey(module.identifier);
      scopes.forEach((scope) => module.disconnectContextForScope(scope));
    }
  };
  var defaultSchema = {
    controllerAttribute: "data-controller",
    actionAttribute: "data-action",
    targetAttribute: "data-target",
    targetAttributeForScope: (identifier) => `data-${identifier}-target`,
    outletAttributeForScope: (identifier, outlet) => `data-${identifier}-${outlet}-outlet`,
    keyMappings: Object.assign(Object.assign({ enter: "Enter", tab: "Tab", esc: "Escape", space: " ", up: "ArrowUp", down: "ArrowDown", left: "ArrowLeft", right: "ArrowRight", home: "Home", end: "End", page_up: "PageUp", page_down: "PageDown" }, objectFromEntries("abcdefghijklmnopqrstuvwxyz".split("").map((c) => [c, c]))), objectFromEntries("0123456789".split("").map((n) => [n, n])))
  };
  function objectFromEntries(array) {
    return array.reduce((memo, [k, v]) => Object.assign(Object.assign({}, memo), { [k]: v }), {});
  }
  var Application = class {
    constructor(element = document.documentElement, schema = defaultSchema) {
      this.logger = console;
      this.debug = false;
      this.logDebugActivity = (identifier, functionName, detail = {}) => {
        if (this.debug) {
          this.logFormattedMessage(identifier, functionName, detail);
        }
      };
      this.element = element;
      this.schema = schema;
      this.dispatcher = new Dispatcher(this);
      this.router = new Router(this);
      this.actionDescriptorFilters = Object.assign({}, defaultActionDescriptorFilters);
    }
    static start(element, schema) {
      const application = new this(element, schema);
      application.start();
      return application;
    }
    async start() {
      await domReady();
      this.logDebugActivity("application", "starting");
      this.dispatcher.start();
      this.router.start();
      this.logDebugActivity("application", "start");
    }
    stop() {
      this.logDebugActivity("application", "stopping");
      this.dispatcher.stop();
      this.router.stop();
      this.logDebugActivity("application", "stop");
    }
    register(identifier, controllerConstructor) {
      this.load({ identifier, controllerConstructor });
    }
    registerActionOption(name, filter) {
      this.actionDescriptorFilters[name] = filter;
    }
    load(head, ...rest) {
      const definitions = Array.isArray(head) ? head : [head, ...rest];
      definitions.forEach((definition) => {
        if (definition.controllerConstructor.shouldLoad) {
          this.router.loadDefinition(definition);
        }
      });
    }
    unload(head, ...rest) {
      const identifiers = Array.isArray(head) ? head : [head, ...rest];
      identifiers.forEach((identifier) => this.router.unloadIdentifier(identifier));
    }
    get controllers() {
      return this.router.contexts.map((context) => context.controller);
    }
    getControllerForElementAndIdentifier(element, identifier) {
      const context = this.router.getContextForElementAndIdentifier(element, identifier);
      return context ? context.controller : null;
    }
    handleError(error2, message, detail) {
      var _a;
      this.logger.error(`%s

%o

%o`, message, error2, detail);
      (_a = window.onerror) === null || _a === void 0 ? void 0 : _a.call(window, message, "", 0, 0, error2);
    }
    logFormattedMessage(identifier, functionName, detail = {}) {
      detail = Object.assign({ application: this }, detail);
      this.logger.groupCollapsed(`${identifier} #${functionName}`);
      this.logger.log("details:", Object.assign({}, detail));
      this.logger.groupEnd();
    }
  };
  function domReady() {
    return new Promise((resolve) => {
      if (document.readyState == "loading") {
        document.addEventListener("DOMContentLoaded", () => resolve());
      } else {
        resolve();
      }
    });
  }
  function ClassPropertiesBlessing(constructor) {
    const classes = readInheritableStaticArrayValues(constructor, "classes");
    return classes.reduce((properties, classDefinition) => {
      return Object.assign(properties, propertiesForClassDefinition(classDefinition));
    }, {});
  }
  function propertiesForClassDefinition(key) {
    return {
      [`${key}Class`]: {
        get() {
          const { classes } = this;
          if (classes.has(key)) {
            return classes.get(key);
          } else {
            const attribute = classes.getAttributeName(key);
            throw new Error(`Missing attribute "${attribute}"`);
          }
        }
      },
      [`${key}Classes`]: {
        get() {
          return this.classes.getAll(key);
        }
      },
      [`has${capitalize(key)}Class`]: {
        get() {
          return this.classes.has(key);
        }
      }
    };
  }
  function OutletPropertiesBlessing(constructor) {
    const outlets = readInheritableStaticArrayValues(constructor, "outlets");
    return outlets.reduce((properties, outletDefinition) => {
      return Object.assign(properties, propertiesForOutletDefinition(outletDefinition));
    }, {});
  }
  function getOutletController(controller, element, identifier) {
    return controller.application.getControllerForElementAndIdentifier(element, identifier);
  }
  function getControllerAndEnsureConnectedScope(controller, element, outletName) {
    let outletController = getOutletController(controller, element, outletName);
    if (outletController)
      return outletController;
    controller.application.router.proposeToConnectScopeForElementAndIdentifier(element, outletName);
    outletController = getOutletController(controller, element, outletName);
    if (outletController)
      return outletController;
  }
  function propertiesForOutletDefinition(name) {
    const camelizedName = namespaceCamelize(name);
    return {
      [`${camelizedName}Outlet`]: {
        get() {
          const outletElement = this.outlets.find(name);
          const selector = this.outlets.getSelectorForOutletName(name);
          if (outletElement) {
            const outletController = getControllerAndEnsureConnectedScope(this, outletElement, name);
            if (outletController)
              return outletController;
            throw new Error(`The provided outlet element is missing an outlet controller "${name}" instance for host controller "${this.identifier}"`);
          }
          throw new Error(`Missing outlet element "${name}" for host controller "${this.identifier}". Stimulus couldn't find a matching outlet element using selector "${selector}".`);
        }
      },
      [`${camelizedName}Outlets`]: {
        get() {
          const outlets = this.outlets.findAll(name);
          if (outlets.length > 0) {
            return outlets.map((outletElement) => {
              const outletController = getControllerAndEnsureConnectedScope(this, outletElement, name);
              if (outletController)
                return outletController;
              console.warn(`The provided outlet element is missing an outlet controller "${name}" instance for host controller "${this.identifier}"`, outletElement);
            }).filter((controller) => controller);
          }
          return [];
        }
      },
      [`${camelizedName}OutletElement`]: {
        get() {
          const outletElement = this.outlets.find(name);
          const selector = this.outlets.getSelectorForOutletName(name);
          if (outletElement) {
            return outletElement;
          } else {
            throw new Error(`Missing outlet element "${name}" for host controller "${this.identifier}". Stimulus couldn't find a matching outlet element using selector "${selector}".`);
          }
        }
      },
      [`${camelizedName}OutletElements`]: {
        get() {
          return this.outlets.findAll(name);
        }
      },
      [`has${capitalize(camelizedName)}Outlet`]: {
        get() {
          return this.outlets.has(name);
        }
      }
    };
  }
  function TargetPropertiesBlessing(constructor) {
    const targets = readInheritableStaticArrayValues(constructor, "targets");
    return targets.reduce((properties, targetDefinition) => {
      return Object.assign(properties, propertiesForTargetDefinition(targetDefinition));
    }, {});
  }
  function propertiesForTargetDefinition(name) {
    return {
      [`${name}Target`]: {
        get() {
          const target = this.targets.find(name);
          if (target) {
            return target;
          } else {
            throw new Error(`Missing target element "${name}" for "${this.identifier}" controller`);
          }
        }
      },
      [`${name}Targets`]: {
        get() {
          return this.targets.findAll(name);
        }
      },
      [`has${capitalize(name)}Target`]: {
        get() {
          return this.targets.has(name);
        }
      }
    };
  }
  function ValuePropertiesBlessing(constructor) {
    const valueDefinitionPairs = readInheritableStaticObjectPairs(constructor, "values");
    const propertyDescriptorMap = {
      valueDescriptorMap: {
        get() {
          return valueDefinitionPairs.reduce((result, valueDefinitionPair) => {
            const valueDescriptor = parseValueDefinitionPair(valueDefinitionPair, this.identifier);
            const attributeName = this.data.getAttributeNameForKey(valueDescriptor.key);
            return Object.assign(result, { [attributeName]: valueDescriptor });
          }, {});
        }
      }
    };
    return valueDefinitionPairs.reduce((properties, valueDefinitionPair) => {
      return Object.assign(properties, propertiesForValueDefinitionPair(valueDefinitionPair));
    }, propertyDescriptorMap);
  }
  function propertiesForValueDefinitionPair(valueDefinitionPair, controller) {
    const definition = parseValueDefinitionPair(valueDefinitionPair, controller);
    const { key, name, reader: read, writer: write } = definition;
    return {
      [name]: {
        get() {
          const value = this.data.get(key);
          if (value !== null) {
            return read(value);
          } else {
            return definition.defaultValue;
          }
        },
        set(value) {
          if (value === void 0) {
            this.data.delete(key);
          } else {
            this.data.set(key, write(value));
          }
        }
      },
      [`has${capitalize(name)}`]: {
        get() {
          return this.data.has(key) || definition.hasCustomDefaultValue;
        }
      }
    };
  }
  function parseValueDefinitionPair([token, typeDefinition], controller) {
    return valueDescriptorForTokenAndTypeDefinition({
      controller,
      token,
      typeDefinition
    });
  }
  function parseValueTypeConstant(constant) {
    switch (constant) {
      case Array:
        return "array";
      case Boolean:
        return "boolean";
      case Number:
        return "number";
      case Object:
        return "object";
      case String:
        return "string";
    }
  }
  function parseValueTypeDefault(defaultValue) {
    switch (typeof defaultValue) {
      case "boolean":
        return "boolean";
      case "number":
        return "number";
      case "string":
        return "string";
    }
    if (Array.isArray(defaultValue))
      return "array";
    if (Object.prototype.toString.call(defaultValue) === "[object Object]")
      return "object";
  }
  function parseValueTypeObject(payload) {
    const { controller, token, typeObject } = payload;
    const hasType = isSomething(typeObject.type);
    const hasDefault = isSomething(typeObject.default);
    const fullObject = hasType && hasDefault;
    const onlyType = hasType && !hasDefault;
    const onlyDefault = !hasType && hasDefault;
    const typeFromObject = parseValueTypeConstant(typeObject.type);
    const typeFromDefaultValue = parseValueTypeDefault(payload.typeObject.default);
    if (onlyType)
      return typeFromObject;
    if (onlyDefault)
      return typeFromDefaultValue;
    if (typeFromObject !== typeFromDefaultValue) {
      const propertyPath = controller ? `${controller}.${token}` : token;
      throw new Error(`The specified default value for the Stimulus Value "${propertyPath}" must match the defined type "${typeFromObject}". The provided default value of "${typeObject.default}" is of type "${typeFromDefaultValue}".`);
    }
    if (fullObject)
      return typeFromObject;
  }
  function parseValueTypeDefinition(payload) {
    const { controller, token, typeDefinition } = payload;
    const typeObject = { controller, token, typeObject: typeDefinition };
    const typeFromObject = parseValueTypeObject(typeObject);
    const typeFromDefaultValue = parseValueTypeDefault(typeDefinition);
    const typeFromConstant = parseValueTypeConstant(typeDefinition);
    const type = typeFromObject || typeFromDefaultValue || typeFromConstant;
    if (type)
      return type;
    const propertyPath = controller ? `${controller}.${typeDefinition}` : token;
    throw new Error(`Unknown value type "${propertyPath}" for "${token}" value`);
  }
  function defaultValueForDefinition(typeDefinition) {
    const constant = parseValueTypeConstant(typeDefinition);
    if (constant)
      return defaultValuesByType[constant];
    const hasDefault = hasProperty(typeDefinition, "default");
    const hasType = hasProperty(typeDefinition, "type");
    const typeObject = typeDefinition;
    if (hasDefault)
      return typeObject.default;
    if (hasType) {
      const { type } = typeObject;
      const constantFromType = parseValueTypeConstant(type);
      if (constantFromType)
        return defaultValuesByType[constantFromType];
    }
    return typeDefinition;
  }
  function valueDescriptorForTokenAndTypeDefinition(payload) {
    const { token, typeDefinition } = payload;
    const key = `${dasherize(token)}-value`;
    const type = parseValueTypeDefinition(payload);
    return {
      type,
      key,
      name: camelize(key),
      get defaultValue() {
        return defaultValueForDefinition(typeDefinition);
      },
      get hasCustomDefaultValue() {
        return parseValueTypeDefault(typeDefinition) !== void 0;
      },
      reader: readers[type],
      writer: writers[type] || writers.default
    };
  }
  var defaultValuesByType = {
    get array() {
      return [];
    },
    boolean: false,
    number: 0,
    get object() {
      return {};
    },
    string: ""
  };
  var readers = {
    array(value) {
      const array = JSON.parse(value);
      if (!Array.isArray(array)) {
        throw new TypeError(`expected value of type "array" but instead got value "${value}" of type "${parseValueTypeDefault(array)}"`);
      }
      return array;
    },
    boolean(value) {
      return !(value == "0" || String(value).toLowerCase() == "false");
    },
    number(value) {
      return Number(value.replace(/_/g, ""));
    },
    object(value) {
      const object = JSON.parse(value);
      if (object === null || typeof object != "object" || Array.isArray(object)) {
        throw new TypeError(`expected value of type "object" but instead got value "${value}" of type "${parseValueTypeDefault(object)}"`);
      }
      return object;
    },
    string(value) {
      return value;
    }
  };
  var writers = {
    default: writeString,
    array: writeJSON,
    object: writeJSON
  };
  function writeJSON(value) {
    return JSON.stringify(value);
  }
  function writeString(value) {
    return `${value}`;
  }
  var Controller = class {
    constructor(context) {
      this.context = context;
    }
    static get shouldLoad() {
      return true;
    }
    static afterLoad(_identifier, _application) {
      return;
    }
    get application() {
      return this.context.application;
    }
    get scope() {
      return this.context.scope;
    }
    get element() {
      return this.scope.element;
    }
    get identifier() {
      return this.scope.identifier;
    }
    get targets() {
      return this.scope.targets;
    }
    get outlets() {
      return this.scope.outlets;
    }
    get classes() {
      return this.scope.classes;
    }
    get data() {
      return this.scope.data;
    }
    initialize() {
    }
    connect() {
    }
    disconnect() {
    }
    dispatch(eventName, { target = this.element, detail = {}, prefix = this.identifier, bubbles = true, cancelable = true } = {}) {
      const type = prefix ? `${prefix}:${eventName}` : eventName;
      const event = new CustomEvent(type, { detail, bubbles, cancelable });
      target.dispatchEvent(event);
      return event;
    }
  };
  Controller.blessings = [
    ClassPropertiesBlessing,
    TargetPropertiesBlessing,
    ValuePropertiesBlessing,
    OutletPropertiesBlessing
  ];
  Controller.targets = [];
  Controller.outlets = [];
  Controller.values = {};

  // app/javascript/application.js
  window.Stimulus = Application.start();
  initAll();
})();
/*! Bundled license information:

govuk-frontend/dist/govuk/components/accordion/accordion.mjs:
  (**
   * Accordion component
   *
   * This allows a collection of sections to be collapsed by default, showing only
   * their headers. Sections can be expanded or collapsed individually by clicking
   * their headers. A "Show all sections" button is also added to the top of the
   * accordion, which switches to "Hide all sections" when all the sections are
   * expanded.
   *
   * The state of each section is saved to the DOM via the `aria-expanded`
   * attribute, which also provides accessibility.
   *
   * @preserve
   * @augments ConfigurableComponent<AccordionConfig>
   *)

govuk-frontend/dist/govuk/components/button/button.mjs:
  (**
   * JavaScript enhancements for the Button component
   *
   * @preserve
   * @augments ConfigurableComponent<ButtonConfig>
   *)

govuk-frontend/dist/govuk/components/character-count/character-count.mjs:
  (**
   * Character count component
   *
   * Tracks the number of characters or words in the `.govuk-js-character-count`
   * `<textarea>` inside the element. Displays a message with the remaining number
   * of characters/words available, or the number of characters/words in excess.
   *
   * You can configure the message to only appear after a certain percentage
   * of the available characters/words has been entered.
   *
   * @preserve
   * @augments ConfigurableComponent<CharacterCountConfig>
   *)

govuk-frontend/dist/govuk/components/checkboxes/checkboxes.mjs:
  (**
   * Checkboxes component
   *
   * @preserve
   *)

govuk-frontend/dist/govuk/components/error-summary/error-summary.mjs:
  (**
   * Error summary component
   *
   * Takes focus on initialisation for accessible announcement, unless disabled in
   * configuration.
   *
   * @preserve
   * @augments ConfigurableComponent<ErrorSummaryConfig>
   *)

govuk-frontend/dist/govuk/components/exit-this-page/exit-this-page.mjs:
  (**
   * Exit this page component
   *
   * @preserve
   * @augments ConfigurableComponent<ExitThisPageConfig>
   *)

govuk-frontend/dist/govuk/components/file-upload/file-upload.mjs:
  (**
   * File upload component
   *
   * @preserve
   * @augments ConfigurableComponent<FileUploadConfig>
   *)

govuk-frontend/dist/govuk/components/header/header.mjs:
  (**
   * Header component
   *
   * @preserve
   *)

govuk-frontend/dist/govuk/components/notification-banner/notification-banner.mjs:
  (**
   * Notification Banner component
   *
   * @preserve
   * @augments ConfigurableComponent<NotificationBannerConfig>
   *)

govuk-frontend/dist/govuk/components/password-input/password-input.mjs:
  (**
   * Password input component
   *
   * @preserve
   * @augments ConfigurableComponent<PasswordInputConfig>
   *)

govuk-frontend/dist/govuk/components/radios/radios.mjs:
  (**
   * Radios component
   *
   * @preserve
   *)

govuk-frontend/dist/govuk/components/service-navigation/service-navigation.mjs:
  (**
   * Service Navigation component
   *
   * @preserve
   *)

govuk-frontend/dist/govuk/components/skip-link/skip-link.mjs:
  (**
   * Skip link component
   *
   * @preserve
   * @augments Component<HTMLAnchorElement>
   *)

govuk-frontend/dist/govuk/components/tabs/tabs.mjs:
  (**
   * Tabs component
   *
   * @preserve
   *)
*/
//# sourceMappingURL=application.js.map
