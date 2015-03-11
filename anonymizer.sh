#!/bin/bash
echo "*** This script is anonymizing a DB-dump of the LIVE-DB in the DEMO-Environment ***"

PATH_TO_ROOT=$1

HOST=`grep host $PATH_TO_ROOT/app/etc/local.xml | sed 's/ *<host>\(.*\)<\/host>/\1/' | sed 's/<!\[CDATA\[//' | sed 's/\]\]>//'`
USER=`grep username $PATH_TO_ROOT/app/etc/local.xml | sed 's/ *<username>\(.*\)<\/username>/\1/' | sed 's/<!\[CDATA\[//' | sed 's/\]\]>//'`
PASS=`grep password $PATH_TO_ROOT/app/etc/local.xml | sed 's/ *<password>\(.*\)<\/password>/\1/' | sed 's/<!\[CDATA\[//' | sed 's/\]\]>//'`
NAME=`grep dbname $PATH_TO_ROOT/app/etc/local.xml | sed 's/ *<dbname>\(.*\)<\/dbname>/\1/' | sed 's/<!\[CDATA\[//' | sed 's/\]\]>//'`

DEV_IDENTIFIERS=".*(dev|stage|staging|test|anonym).*"
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
        exit
    fi
fi

if [ "$PASS" = "" ]; then
    DBCALL="mysql -u$USER -h$HOST $NAME"
    DBDUMPCALL="mysqldump -u$USER -h$HOST $NAME"
else
    DBCALL="mysql -u$USER -p$PASS -h$HOST $NAME"
    DBDUMPCALL="mysqldump -u$USER -p$PASS -h$HOST $NAME"
fi



echo "* Step  1: Anonymize Names and eMails"
# admin user
$DBCALL -e "UPDATE admin_user SET password=MD5(CONCAT(username,'123'))"

# api user
$DBCALL -e "UPDATE api_user SET api_key=MD5(CONCAT(username,'123'))"

# customer address
ENTITY_TYPE="customer_address"
ATTR_CODE="firstname"
$DBCALL -e "UPDATE customer_address_entity_varchar SET value=CONCAT('firstname_',entity_id) WHERE attribute_id=(select attribute_id from eav_attribute where attribute_code='$ATTR_CODE' and entity_type_id=(select entity_type_id from eav_entity_type where entity_type_code='$ENTITY_TYPE'))"
ATTR_CODE="lastname"
$DBCALL -e "UPDATE customer_address_entity_varchar SET value=CONCAT('lastname_',entity_id) WHERE attribute_id=(select attribute_id from eav_attribute where attribute_code='$ATTR_CODE' and entity_type_id=(select entity_type_id from eav_entity_type where entity_type_code='$ENTITY_TYPE'))"
ATTR_CODE="telephone"
$DBCALL -e "UPDATE customer_address_entity_varchar SET value=CONCAT('0341 12345',entity_id) WHERE attribute_id=(select attribute_id from eav_attribute where attribute_code='$ATTR_CODE' and entity_type_id=(select entity_type_id from eav_entity_type where entity_type_code='$ENTITY_TYPE'))"
ATTR_CODE="fax"
$DBCALL -e "UPDATE customer_address_entity_varchar SET value=CONCAT('0171 12345',entity_id) WHERE attribute_id=(select attribute_id from eav_attribute where attribute_code='$ATTR_CODE' and entity_type_id=(select entity_type_id from eav_entity_type where entity_type_code='$ENTITY_TYPE'))"
ATTR_CODE="street"
$DBCALL -e "UPDATE customer_address_entity_text SET value=CONCAT(entity_id,' test avenue') WHERE attribute_id=(select attribute_id from eav_attribute where attribute_code='$ATTR_CODE' and entity_type_id=(select entity_type_id from eav_entity_type where entity_type_code='$ENTITY_TYPE'))"

# customer account data
ENTITY_TYPE="customer"
$DBCALL -e "UPDATE customer_entity SET email=CONCAT('dev_',entity_id,'@trash-mail.com')"
ATTR_CODE="firstname"
$DBCALL -e "UPDATE customer_entity_varchar SET value=CONCAT('firstname_',entity_id) WHERE attribute_id=(select attribute_id from eav_attribute where attribute_code='$ATTR_CODE' and entity_type_id=(select entity_type_id from eav_entity_type where entity_type_code='$ENTITY_TYPE'))"
ATTR_CODE="lastname"
$DBCALL -e "UPDATE customer_entity_varchar SET value=CONCAT('lastname_',entity_id) WHERE attribute_id=(select attribute_id from eav_attribute where attribute_code='$ATTR_CODE' and entity_type_id=(select entity_type_id from eav_entity_type where entity_type_code='$ENTITY_TYPE'))"
ATTR_CODE="password_hash"
$DBCALL -e "UPDATE customer_entity_varchar SET value=MD5(CONCAT('dev_',entity_id,'@trash-mail.com')) WHERE attribute_id=(select attribute_id from eav_attribute where attribute_code='$ATTR_CODE' and entity_type_id=(select entity_type_id from eav_entity_type where entity_type_code='$ENTITY_TYPE'))"

# credit memo
$DBCALL -e "UPDATE sales_flat_creditmemo_grid SET billing_name='Demo User'"

# invoices
$DBCALL -e "UPDATE sales_flat_invoice_grid SET billing_name='Demo User'"

# shipments
$DBCALL -e "UPDATE sales_flat_shipment_grid SET shipping_name='Demo User'"

# quotes
$DBCALL -e "UPDATE sales_flat_quote SET customer_email=CONCAT('dev_',entity_id,'@trash-mail.com'), customer_firstname='Demo', customer_lastname='User', customer_middlename='Dev', remote_ip='192.168.1.1', password_hash=NULL"
$DBCALL -e "UPDATE sales_flat_quote_address SET firstname='Demo', lastname='User', company=NULL, telephone=CONCAT('0123-4567', address_id), street=CONCAT('Devstreet ',address_id)"

# orders
$DBCALL -e "UPDATE sales_flat_order SET customer_email=CONCAT('dev_',entity_id,'@trash-mail.com'), customer_firstname='Demo', customer_lastname='User', customer_middlename='Dev'"
$DBCALL -e "UPDATE sales_flat_order_address SET firstname='Demo', lastname='User', company=NULL, telephone=CONCAT('0123-4567', entity_id), street=CONCAT('Devstreet ',entity_id)"
$DBCALL -e "UPDATE sales_flat_order_grid SET shipping_name='Demo D. User', billing_name='Demo D. User'"

# payments
$DBCALL -e "UPDATE sales_flat_order_payment SET additional_data=NULL, additional_information=NULL"

# newsletter
$DBCALL -e "UPDATE newsletter_subscriber SET subscriber_email=CONCAT('dev_newsletter_',subscriber_id,'@trash-mail.com')"

# truncate unrequired tables
$DBCALL -e "TRUNCATE log_url"
$DBCALL -e "TRUNCATE log_url_info"
$DBCALL -e "TRUNCATE log_visitor"
$DBCALL -e "TRUNCATE log_visitor_info"
$DBCALL -e "TRUNCATE report_event"




echo "* Step 2: Mod Config."
# disable assets merging, google analytics and robots
$DBCALL -e "UPDATE core_config_data SET value='1' WHERE path='design/head/demonotice'"
$DBCALL -e "UPDATE core_config_data SET value='0' WHERE path='dev/css/merge_css_files' OR path='dev/js/merge_files'"
$DBCALL -e "UPDATE core_config_data SET value='0' WHERE path='google/analytics/active'"
$DBCALL -e "UPDATE core_config_data SET value='NOINDEX,NOFOLLOW' WHERE path='design/head/default_robots'"

# set base urls
$DBCALL -e "UPDATE core_config_data SET value='{{base_url}}' WHERE path='web/unsecure/base_url'"
$DBCALL -e "UPDATE core_config_data SET value='{{base_url}}' WHERE path='web/secure/base_url'"

# set mail receivers
$DBCALL -e "UPDATE core_config_data SET value='contact-magento-dev@trash-mail.com' WHERE path='trans_email/ident_general/email'"
$DBCALL -e "UPDATE core_config_data SET value='contact-magento-dev@trash-mail.com' WHERE path='trans_email/ident_sales/email'"
$DBCALL -e "UPDATE core_config_data SET value='contact-magento-dev@trash-mail.com' WHERE path='trans_email/ident_support/email'"
$DBCALL -e "UPDATE core_config_data SET value='contact-magento-dev@trash-mail.com' WHERE path='trans_email/ident_custom1/email'"
$DBCALL -e "UPDATE core_config_data SET value='contact-magento-dev@trash-mail.com' WHERE path='trans_email/ident_custom2/email'"

# increase increment ids
$DBCALL -e "UPDATE eav_entity_store SET increment_last_id=10*increment_last_id"

# set test mode everywhere
$DBCALL -e "UPDATE core_config_data SET value='test' WHERE value LIKE 'live'"
$DBCALL -e "UPDATE core_config_data SET value='test' WHERE value LIKE 'prod'"
$DBCALL -e "UPDATE core_config_data SET value=1 WHERE path LIKE '%/testmode'"

echo "Done."
