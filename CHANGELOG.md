## [0.1.1] - 2024-07-09

- Bugfix step model name:
  Preserve the original i18n_key value when overriding ActiveModel::Model.model_name

    eg.

        RootModule::SubModule::SomeStep # should produce the i18n key
        :root_module/sub_module/some_step

    This will have side effects for everyone that is using 0.1.0

    It is recommend to update the translations to use the full model name of
    your steps.

## [0.1.0] - 2024-06-11

- Initial release
