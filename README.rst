Magento DB anonymizer
=====================

This is a shell script to anonymize a Magento database.

Usage
-----

``./anonymize.sh [-c path/to/your/config] [path/to/magento/root]``

You don't need to specify the path to your Magento root, if you call the
anonymizer from this directory.

Configuration will be read from the configuration path specified with ``-c``.
If it was not specified, it will be read from a file ``.anonymizer.cfg`` in your
Magento root, which is recommended.

If no configuration exists or if it is incomplete, the missing settings will be
requested interactively.

Result
------

Admin and API accounts
~~~~~~~~~~~~~~~~~~~~~~

If you anonymized admin or api accounts, there usernames will be untouched, but
there passwords will be reset to username + "123".

User accounts
~~~~~~~~~~~~~

If you decide to anonymize user accounts, you may exclude some customer emails
from anonymization, but this affects only email and password – all other user
data will be anonymized nevertheless.

Anonymized user accounts will be changed to email and password
"dev\_" + entity_id + "@trash-mail.com".

Logs
~~~~

Log tables can be truncated.

Magento Configuration
~~~~~~~~~~~~~~~~~~~~~

You can enable the demostore notice.

In General, it is tried to disable all production-related settings such as

* Merging CSS/JS files
* Google Analytics tracking
* Robots (will be set to "NOINDEX,NOFOLLOW")
* mail receivers (will be set to "contact-magento-dev@trash-mail.com")
* base urls (you might enter a base url per storeview or use the default one,
  which is determined by Magento at runtime)
* increment_last_id is getting reset to a random value
* trying to set all config settings from "prod" or "live" to "test"
* Payone configuration (by requesting alternate account data)

Configuration
-------------

There are some questions asked during anonymization run. After the first run,
you will be asked to save your configuration, so these questions won't be asked
again.

Disclaimer
----------

Please remember, that data depend on your customizations and the extensions
installed in your store. If you find something that was not anonymized, please
let me know.
