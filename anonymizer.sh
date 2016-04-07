#!/bin/bash
echo "*** This script is anonymizing a DB-dump of the LIVE-DB in the DEMO-Environment ***"

PATH_TO_ROOT=$1
if [[ "$PATH_TO_ROOT" == "" && -f "app/etc/local.xml" ]]; then
  PATH_TO_ROOT="."
fi
if [[ "$PATH_TO_ROOT" == "" ]]; then
  echo "Please specify the path to your Magento store"
  exit 1
fi
CONFIG=$PATH_TO_ROOT"/.anonymizer.cfg"

if [[ 1 < $# ]]; then
  if [[ "-c" == "$1" ]]; then
    PATH_TO_ROOT=$3
    CONFIG=$2
    if [[ ! -f $CONFIG ]]; then
      echo -e "\E[1;31mCaution: \E[0mConfiguration file $CONFIG does not exist, yet! You will be asked to create it after the anonymization run."
      echo "Do you want to continue (Y/n)?"; read CONTINUE;
      if [[ ! -z "$CONTINUE" && "$CONTINUE" != "y" && "$CONTINUE" != "Y" ]]; then
        exit;
      fi
    fi
  fi
fi


while [[ ! -f $PATH_TO_ROOT/app/etc/local.xml ]]; do
  echo "$PATH_TO_ROOT is no valid Magento root folder. Please enter the correct path:"
  read PATH_TO_ROOT
done

HOST=`grep host $PATH_TO_ROOT/app/etc/local.xml | sed 's/ *<host>\(.*\)<\/host>/\1/' | sed 's/<!\[CDATA\[//' | sed 's/\]\]>//'`
USER=`grep username $PATH_TO_ROOT/app/etc/local.xml | sed 's/ *<username>\(.*\)<\/username>/\1/' | sed 's/<!\[CDATA\[//' | sed 's/\]\]>//'`
PASS=`grep password $PATH_TO_ROOT/app/etc/local.xml | sed 's/ *<password>\(.*\)<\/password>/\1/' | sed 's/<!\[CDATA\[//' | sed 's/\]\]>//'`
NAME=`grep dbname $PATH_TO_ROOT/app/etc/local.xml | sed 's/ *<dbname>\(.*\)<\/dbname>/\1/' | sed 's/<!\[CDATA\[//' | sed 's/\]\]>//'`

if [[ -f "$CONFIG" ]]; then
  echo "Using configuration file $CONFIG"
  source "$CONFIG"
fi

if [[ -z "$DEV_IDENTIFIERS" ]]; then
  DEV_IDENTIFIERS=".*(dev|stage|staging|test|anonym).*"
fi
if [[ $NAME =~ $DEV_IDENTIFIERS ]]; then
    echo "We are on the TEST environment, everything is fine"
else
    echo ""
    echo "IT SEEMS THAT WE ARE ON THE PRODUCTION ENVIRONMENT!"
    echo ""
    echo "If you are sure, this is a test environment, please type 'test' to continue"
    read force
    if [[ "$force" != "test" ]]; then
        echo "Canceled"
        exit 2
    fi
fi

if [ "$PASS" = "" ]; then
    DBCALL="mysql -u$USER -h$HOST $NAME -e"
    DBDUMPCALL="mysqldump -u$USER -h$HOST $NAME"
else
    DBCALL="mysql -u$USER -p$PASS -h$HOST $NAME -e"
    DBDUMPCALL="mysqldump -u$USER -p$PASS -h$HOST $NAME"
fi

echo "* Step 1: Anonymize Names and eMails"

if [[ -z "$RESET_ADMIN_PASSWORDS" ]]; then
  echo "  Do you want me to reset admin user passwords (Y/n)?"; read RESET_ADMIN_PASSWORDS
fi
if [[ "$RESET_ADMIN_PASSWORDS" == "y" || "$RESET_ADMIN_PASSWORDS" == "Y" || -z "$RESET_ADMIN_PASSWORDS" ]]; then
  RESET_ADMIN_PASSWORDS="y"
  # admin user
  $DBCALL "UPDATE admin_user SET password=MD5(CONCAT(username,'123'))"
fi

if [[ -z "$RESET_API_PASSWORDS" ]]; then
  echo "  Do you want me to reset API user passwords (Y/n)?"; read RESET_API_PASSWORDS
fi
if [[  "$RESET_API_PASSWORDS" == "y" || "$RESET_API_PASSWORDS" == "Y" || -z "$RESET_API_PASSWORDS" ]]; then
  RESET_API_PASSWORDS="y"
  # api user
  $DBCALL "UPDATE api_user SET api_key=MD5(CONCAT(username,'123'))"
fi

if [[ -z "$ANONYMIZE" ]]; then
  echo "  Do you want me to anonymize your database (Y/n)?"; read ANONYMIZE
fi
if [[ "$ANONYMIZE" == "y" || "$ANONYMIZE" == "Y" || -z "$ANONYMIZE" ]]; then
  ANONYMIZE="y"
  # customer address
  ENTITY_TYPE="customer_address"
  ATTR_CODE="firstname"
  $DBCALL "UPDATE customer_address_entity_varchar SET value=CONCAT('firstname_',entity_id) WHERE attribute_id=(select attribute_id from eav_attribute where attribute_code='$ATTR_CODE' and entity_type_id=(select entity_type_id from eav_entity_type where entity_type_code='$ENTITY_TYPE'))"
  ATTR_CODE="lastname"
  $DBCALL "UPDATE customer_address_entity_varchar SET value=CONCAT('lastname_',entity_id) WHERE attribute_id=(select attribute_id from eav_attribute where attribute_code='$ATTR_CODE' and entity_type_id=(select entity_type_id from eav_entity_type where entity_type_code='$ENTITY_TYPE'))"
  ATTR_CODE="telephone"
  $DBCALL "UPDATE customer_address_entity_varchar SET value=CONCAT('0341 12345',entity_id) WHERE attribute_id=(select attribute_id from eav_attribute where attribute_code='$ATTR_CODE' and entity_type_id=(select entity_type_id from eav_entity_type where entity_type_code='$ENTITY_TYPE'))"
  ATTR_CODE="fax"
  $DBCALL "UPDATE customer_address_entity_varchar SET value=CONCAT('0171 12345',entity_id) WHERE attribute_id=(select attribute_id from eav_attribute where attribute_code='$ATTR_CODE' and entity_type_id=(select entity_type_id from eav_entity_type where entity_type_code='$ENTITY_TYPE'))"
  ATTR_CODE="street"
  $DBCALL "UPDATE customer_address_entity_text SET value=CONCAT(entity_id,' test avenue') WHERE attribute_id=(select attribute_id from eav_attribute where attribute_code='$ATTR_CODE' and entity_type_id=(select entity_type_id from eav_entity_type where entity_type_code='$ENTITY_TYPE'))"

  # customer account data
  if [[ -z "$KEEP_EMAIL" ]]; then
    echo "  If you want to keep some users credentials, please enter corresponding email addresses quoted by '\"' separated by comma (default: none):"; read KEEP_EMAIL
  fi
  ERRORS_KEEP_MAIL=`echo "$KEEP_EMAIL" | grep -vP -e '(\"[^\"]+@[^\"]+\")(, ?(\"[^\"]+@[^\"]+\"))*'`
  if [[ ! -z "$ERRORS_KEEP_MAIL" ]]; then
    while [[ ! -z "$ERRORS_KEEP_MAIL" ]]; do
      echo -e "\E[1;31mInvalid input! \E[0mExample: \"foo@bar.com\",\"me@example.com\"."
      echo "  If you want to keep some users credentials, please enter corresponding email addresses quoted by '\"' separated by comma (default: none):"; read KEEP_EMAIL
      ERRORS_KEEP_MAIL=`echo "$KEEP_EMAIL" | grep -vP -e '(\"[^\"]+@[^\"]+\")(, ?(\"[^\"]+@[^\"]+\"))*'`
      if [[ -z "$KEEP_MAIL" ]]; then
        break
      fi
    done
    if [[ ! -z "$KEEP_EMAIL" ]]; then
      echo "  Keeping $KEEP_EMAIL"
    fi
  fi

  ENTITY_TYPE="customer"
  $DBCALL "UPDATE customer_entity SET email=CONCAT('dev_',entity_id,'@trash-mail.com') WHERE email NOT IN ($KEEP_EMAIL)"
  ATTR_CODE="firstname"
  $DBCALL "UPDATE customer_entity_varchar SET value=CONCAT('firstname_',entity_id) WHERE attribute_id=(select attribute_id from eav_attribute where attribute_code='$ATTR_CODE' and entity_type_id=(select entity_type_id from eav_entity_type where entity_type_code='$ENTITY_TYPE'))"
  ATTR_CODE="lastname"
  $DBCALL "UPDATE customer_entity_varchar SET value=CONCAT('lastname_',entity_id) WHERE attribute_id=(select attribute_id from eav_attribute where attribute_code='$ATTR_CODE' and entity_type_id=(select entity_type_id from eav_entity_type where entity_type_code='$ENTITY_TYPE'))"
  ATTR_CODE="password_hash"
  $DBCALL "UPDATE customer_entity_varchar v SET value=MD5(CONCAT('dev_',entity_id,'@trash-mail.com')) WHERE attribute_id=(select attribute_id from eav_attribute where attribute_code='$ATTR_CODE' and entity_type_id=(select entity_type_id from eav_entity_type where entity_type_code='$ENTITY_TYPE')) AND (SELECT email FROM customer_entity e WHERE e.entity_id=v.entity_id AND email NOT IN ($KEEP_EMAIL))"

  # credit memo
  $DBCALL "UPDATE sales_flat_creditmemo_grid SET billing_name='Demo User'"

  # invoices
  $DBCALL "UPDATE sales_flat_invoice_grid SET billing_name='Demo User'"

  # shipments
  $DBCALL "UPDATE sales_flat_shipment_grid SET shipping_name='Demo User'"

  # quotes
  $DBCALL "UPDATE sales_flat_quote SET customer_email=CONCAT('dev_',entity_id,'@trash-mail.com'), customer_firstname='Demo', customer_lastname='User', customer_middlename='Dev', remote_ip='192.168.1.1', password_hash=NULL WHERE customer_email NOT IN ($KEEP_EMAIL)"
  $DBCALL "UPDATE sales_flat_quote_address SET firstname='Demo', lastname='User', company=NULL, telephone=CONCAT('0123-4567', address_id), street=CONCAT('Devstreet ',address_id)"

  # orders
  $DBCALL "UPDATE sales_flat_order SET customer_email=CONCAT('dev_',entity_id,'@trash-mail.com'), customer_firstname='Demo', customer_lastname='User', customer_middlename='Dev'"
  $DBCALL "UPDATE sales_flat_order_address SET email=CONCAT('dev_',entity_id,'@trash-mail.com'), firstname='Demo', lastname='User', company=NULL, telephone=CONCAT('0123-4567', entity_id), street=CONCAT('Devstreet ',entity_id)"
  $DBCALL "UPDATE sales_flat_order_grid SET shipping_name='Demo D. User', billing_name='Demo D. User'"

  # payments
  $DBCALL "UPDATE sales_flat_order_payment SET additional_data=NULL, additional_information=NULL"

  # newsletter
  $DBCALL "UPDATE newsletter_subscriber SET subscriber_email=CONCAT('dev_newsletter_',subscriber_id,'@trash-mail.com') WHERE subscriber_email NOT IN ($KEEP_EMAIL)"
fi

if [[ -z "$TRUNCATE_LOGS" ]]; then
  echo "  Do you want me to truncate log tables (Y/n)?"; read TRUNCATE_LOGS
fi
if [[  "$TRUNCATE_LOGS" == "y" || "$TRUNCATE_LOGS" == "Y" || -z "$TRUNCATE_LOGS" ]]; then
  TRUNCATE_LOGS="y"
  # truncate unrequired tables
  $DBCALL "TRUNCATE log_url"
  $DBCALL "TRUNCATE log_url_info"
  $DBCALL "TRUNCATE log_visitor"
  $DBCALL "TRUNCATE log_visitor_info"
  $DBCALL "TRUNCATE report_event"
fi

echo "* Step 2: Mod Config."
# disable assets merging, google analytics and robots
if [[ -z "$DEMO_NOTICE" ]]; then
  echo "  Do you want me to enable demo notice (Y/n)?"; read DEMO_NOTICE
fi
if [[  "$DEMO_NOTICE" == "y" || "$DEMO_NOTICE" == "Y" || -z "$DEMO_NOTICE" ]]; then
  DEMO_NOTICE="y"
  $DBCALL "UPDATE core_config_data SET value='1' WHERE path='design/head/demonotice'"
fi
$DBCALL "UPDATE core_config_data SET value='0' WHERE path='dev/css/merge_css_files' OR path='dev/js/merge_files'"
$DBCALL "UPDATE core_config_data SET value='0' WHERE path='google/analytics/active'"
$DBCALL "UPDATE core_config_data SET value='NOINDEX,NOFOLLOW' WHERE path='design/head/default_robots'"

# set mail receivers
$DBCALL "UPDATE core_config_data SET value='contact-magento-dev@trash-mail.com' WHERE path='trans_email/ident_general/email'"
$DBCALL "UPDATE core_config_data SET value='contact-magento-dev@trash-mail.com' WHERE path='trans_email/ident_sales/email'"
$DBCALL "UPDATE core_config_data SET value='contact-magento-dev@trash-mail.com' WHERE path='trans_email/ident_support/email'"
$DBCALL "UPDATE core_config_data SET value='contact-magento-dev@trash-mail.com' WHERE path='trans_email/ident_custom1/email'"
$DBCALL "UPDATE core_config_data SET value='contact-magento-dev@trash-mail.com' WHERE path='trans_email/ident_custom2/email'"

# set base urls
$DBCALL "UPDATE core_config_data SET value='{{base_url}}' WHERE path='web/unsecure/base_url'"
$DBCALL "UPDATE core_config_data SET value='{{base_url}}' WHERE path='web/secure/base_url'"


# increase increment ids
## generate random number from 10 to 100
function genRandomChar() {

  factor=$RANDOM;
  min=65
  max=90
  let "factor %= $max-$min"
  let "factor += $min";

  printf \\$(printf '%03o' $(($factor)))
}
PREFIX="`genRandomChar``genRandomChar``genRandomChar`"
$DBCALL "UPDATE eav_entity_store SET increment_last_id=NULL, increment_prefix=CONCAT(store_id, '-', '$PREFIX', '-')"

# set test mode everywhere
$DBCALL "UPDATE core_config_data SET value='test' WHERE value LIKE 'live'"
$DBCALL "UPDATE core_config_data SET value='test' WHERE value LIKE 'prod'"
$DBCALL "UPDATE core_config_data SET value=1 WHERE path LIKE '%/testmode'"

# handle PAYONE config
PAYONE_TABLES=`$DBCALL "SHOW TABLES LIKE 'payone_config_payment_method'"`
if [ ! -z "$PAYONE_TABLES" ]; then
  echo "    * Mod PAYONE Config."
  $DBCALL "UPDATE payone_config_payment_method SET mode='test' WHERE mode='live'"
  if [[ -z "$PAYONE_MID" && -z "$PAYONE_PORTALID" && -z "$PAYONE_AID" && -z "$PAYONE_KEY" ]]; then
    echo -e "\E[1;31mCaution: \E[0mYou probably need to change portal IDs and keys for your staging/dev PAYONE payment methods!"
    echo "Please enter your testing/staging/dev merchant ID: "
    read PAYONE_MID
    echo "Please enter your testing/staging/dev portal ID: "
    read PAYONE_PORTALID
    echo "Please enter your testing/staging/dev sub account ID: "
    read PAYONE_AID
    echo "Please enter your testing/staging/dev security key: "
    read PAYONE_KEY
  fi

  $DBCALL "UPDATE core_config_data SET value='$PAYONE_MID' WHERE path='payone_general/global/mid'"
  $DBCALL "UPDATE core_config_data SET value='$PAYONE_PORTALID' WHERE path='payone_general/global/portalid'"
  $DBCALL "UPDATE core_config_data SET value='$PAYONE_AID' WHERE path='payone_general/global/aid'"
  $DBCALL "UPDATE core_config_data SET value='$PAYONE_KEY' WHERE path='payone_general/global/key'"

  $DBCALL "UPDATE payone_config_payment_method SET mid='$PAYONE_MID' WHERE mid IS NOT NULL"
  $DBCALL "UPDATE payone_config_payment_method SET portalid='$PAYONE_PORTALID' WHERE portalid IS NOT NULL"
  $DBCALL "UPDATE payone_config_payment_method SET aid='$PAYONE_AID' WHERE aid IS NOT NULL"
  $DBCALL "UPDATE payone_config_payment_method SET \`key\`='$PAYONE_KEY' WHERE \`key\` IS NOT NULL"
fi

echo "Done."

if [[ ! -f $CONFIG ]]; then
  echo "Do you want to create an anonymizer configuration file based on your answers (Y/n)?"; read CREATE
  if [[  "$CREATE" == "y" || "$CREATE" == "Y" || -z "$CREATE" ]]; then
    echo "DEV_IDENTIFIERS=$DEV_IDENTIFIERS">>$CONFIG
    echo "RESET_ADMIN_PASSWORDS=$RESET_ADMIN_PASSWORDS">>$CONFIG
    echo "RESET_API_PASSWORDS=$RESET_API_PASSWORDS">>$CONFIG
    echo "KEEP_EMAIL=$KEEP_EMAIL">>$CONFIG
    echo "TRUNCATE_LOGS=$TRUNCATE_LOGS">>$CONFIG
    echo "DEMO_NOTICE=$DEMO_NOTICE">>$CONFIG
    if [ ! -z "$PAYONE_TABLES" ]; then
      echo "PAYONE_MID=$PAYONE_MID">>$CONFIG
      echo "PAYONE_PORTALID=$PAYONE_PORTALID">>$CONFIG
      echo "PAYONE_AID=$PAYONE_AID">>$CONFIG
      echo "PAYONE_KEY=$PAYONE_KEY">>$CONFIG
    fi
  fi
fi
