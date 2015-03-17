Magento DB anonymizer
=====================

This is a shell script to anonymize a Magento database.

Usage
-----

``./anonymize.sh [-c path/to/your/config] [path/to/magento/root]``

You don't need to specify the path to your Magento root, if you call the anonymizer from this directory.

Configuration will be read from the configuration path specified with ``-c``. If it was not specified,
it will be read from a file ``.anonymizer.cfg`` in your Magento root, which is recommended.

Configuration
-------------

There are some questions asked during anonymization run. After the first run, you will be asked to save your configuration, so these questions won't be asked again.

Disclaimer
----------

Please remember, that data depend on your customizations and the extensions installed in your store. If you find
something that was not anonymized, please let me know.
