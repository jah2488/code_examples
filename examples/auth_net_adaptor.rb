require 'authorizenet'
require 'net/http'
require 'uri'

module Payments
  class AuthNetAdaptor < PaymentAdaptor
    include AuthorizeNet::API

    CERTIFICATES_DIR      = 'CERTS'.freeze
    MERCHANT_ID_CERT_FILE = 'merchant_id.cer'.freeze
    MERCHANT_ID_PEM_FILE  = 'Certificate.key.pem'.freeze
    MERCHANT_ID_FILE      = 'apple-developer-merchantid-domain-association.txt'.freeze

    def domain_association
      render file: Rails.root + 'CERTS' + MERCHANT_ID_FILE, layout: false
    end

    def validate_merchant
      uri = URI.parse(params[:validationURL])
      http = build_http(uri)

      cert = Rails.root.join(CERTIFICATES_DIR, MERCHANT_ID_CERT_FILE).read
      http.cert = OpenSSL::X509::Certificate.new(cert)

      pem = Rails.root.join(CERTIFICATES_DIR, MERCHANT_ID_PEM_FILE).read
      http.key = OpenSSL::PKey::RSA.new(pem, nil)

      request = build_request(uri)
      response = http.request(request)

      response.body
    end

    def confirm_apple_pay_order
      order = current_order

      transaction = Transaction.new(ENV.fetch("AUTH_NET_LOGIN_ID"), ENV.fetch("AUTH_NET_TRANSACTION_ID"))

      request = build_transaction_request

      response = transaction.create_transaction(request)

      if response.messages&.resultCode == MessageTypeEnum::Ok
        payment = order.payments.create!(
          {
            source: AuthnetAcceptCheckout.create(
              {
                nonce_desc: 'COMMON.APPLE.INAPP.PAYMENT',
                nonce: params[:transaction][:nonce],
                amount: order.total,
                account_number: response.transactionResponse.accountNumber,
                transaction_id: response.transactionResponse.transId,
              }
            ),
            amount: order.total,
            payment_method: payment_method,
            state: "completed"
          }
        )

        order = order.reload

        order.next!
      end

      payment
    end

    private

    def build_transaction_request
      request = CreateTransactionRequest.new
      request.transactionRequest = TransactionRequestType.new
      request.transactionRequest.amount = params[:transaction][:applePayOptions][:amount]
      request.transactionRequest.payment = PaymentType.new
      request.transactionRequest.payment.opaqueData = OpaqueDataType.new('COMMON.APPLE.INAPP.PAYMENT', params[:transaction][:nonce], nil)
      request.transactionRequest.transactionType = TransactionTypeEnum::AuthCaptureTransaction
      request.transactionRequest.lineItems = set_line_items(current_order)
      request.transactionRequest.billTo = set_bill_to(current_order) unless current_order.billing_address.blank?
      request.transactionRequest.shipTo = set_ship_to(current_order) unless current_order.shipping_address.blank?
      request.transactionRequest.customerIP = current_order.last_ip_address unless current_order.last_ip_address.blank?
      request
    end

    def build_http(uri)
      http = ::Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.ssl_version = :TLSv1_2
      http.ciphers = ['ECDHE-RSA-AES128-GCM-SHA256']
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      http
    end

    def build_request(uri)
      request = ::Net::HTTP::Post.new(uri.request_uri, 'Content-Type' => 'application/json')
      body = request_body
      request.body = body.to_json
      request
    end

    def payment_method
      PaymentMethod.find(params[:payment_method_id])
    end

    def set_line_items(current_order)
      LineItems.new(current_order.line_items.map do |li|
        LineItemType.new(li.id,                      # itemId
                         li.name[0..24],             # name
                         li.description[0..254],     # description
                         li.quantity,                # quantity
                         li.price.to_f.round(4),     # unitPrice
                         li.tax_category_id.present? # taxable
                       )
      end)
    end

    def set_bill_to(current_order)
      billing_address = current_order.billing_address
      CustomerAddressType.new(billing_address.firstname,     # firstName
                              billing_address.lastname,      # lastName
                              billing_address.company,       # company
                              billing_address.address1,      # address
                              billing_address.city,          # city
                              billing_address.state&.abbr,   # state
                              billing_address.zipcode,       # zipcode
                              billing_address.country&.name, # country
                              billing_address.phone,         # phoneNumber
                              nil                            # faxNumber
      )
    end

    def set_ship_to(current_order)
      shipping_address = current_order.shipping_address
      NameAndAddressType.new(shipping_address.firstname,     # firstName
                             shipping_address.lastname,      # lastName
                             shipping_address.company,       # company
                             shipping_address.address1,      # address
                             shipping_address.city,          # city
                             shipping_address.state&.abbr,   # state
                             shipping_address.zipcode,       # zipcode
                             shipping_address.country&.name, # country
      )
    end
  end
end
