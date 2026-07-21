require "digest"

module Quickbooks
  class CreateSubmission
    Result = Data.define(:payload, :operation, :replayed)

    def initialize(
      connection:,
      idempotency_key:,
      operation_type:,
      entity_type:,
      entity_label:,
      attributes:,
      creator:,
      serializer:
    )
      @connection = connection
      @idempotency_key = idempotency_key.to_s.downcase
      @operation_type = operation_type
      @entity_type = entity_type
      @entity_label = entity_label
      @attributes = attributes.to_h.stringify_keys
      @creator = creator
      @serializer = serializer
    end

    def call
      validate_idempotency_key!
      operation, created = find_or_create_operation
      return existing_result(operation) unless created

      create_entity(operation)
    end

    private

    attr_reader :attributes,
                :connection,
                :creator,
                :entity_label,
                :entity_type,
                :idempotency_key,
                :operation_type,
                :serializer

    def find_or_create_operation
      operation =
        connection.quickbooks_sync_operations.create!(
          operation_type: operation_type,
          quickbooks_entity_type: entity_type,
          idempotency_key: idempotency_key,
          request_digest: request_digest,
          request_payload: attributes,
          status: "pending"
        )
      [operation, true]
    rescue ActiveRecord::RecordNotUnique
      operation = connection.quickbooks_sync_operations.find_by!(idempotency_key: idempotency_key)
      [operation, false]
    end

    def create_entity(operation)
      entity = creator.call
      payload = serializer.call(entity)
      operation.update!(
        status: "succeeded",
        quickbooks_entity_id: creator.quickbooks_entity_id,
        result_payload: payload,
        completed_at: Time.current
      )

      Result.new(payload: payload, operation: operation, replayed: false)
    rescue Error => error
      operation.update!(
        status: creator.post_attempted? ? "uncertain" : "rejected",
        quickbooks_entity_id: creator.quickbooks_entity_id.presence,
        error_code: error.code.to_s.first(64).presence || "quickbooks_error",
        completed_at: Time.current
      )
      raise
    end

    def existing_result(operation)
      raise_key_conflict! unless matching_request?(operation)

      case operation.status
      when "succeeded"
        Result.new(payload: operation.result_payload.deep_dup, operation: operation, replayed: true)
      when "rejected"
        raise_conflict!(
          "This request was rejected before a confirmed QuickBooks write. Correct it and use a new idempotency key.",
          "idempotency_request_rejected"
        )
      when "uncertain"
        raise_conflict!(
          "The earlier request outcome is uncertain. Check QuickBooks before using a new idempotency key.",
          "idempotency_outcome_uncertain"
        )
      else
        raise_conflict!(
          "This request is already processing or was interrupted. Check QuickBooks before trying again.",
          "idempotency_request_in_progress"
        )
      end
    end

    def matching_request?(operation)
      operation.operation_type == operation_type &&
        operation.quickbooks_entity_type == entity_type &&
        operation.request_digest == request_digest
    end

    def request_digest
      @request_digest ||= Digest::SHA256.hexdigest(JSON.generate(attributes))
    end

    def validate_idempotency_key!
      return if idempotency_key.match?(QuickbooksSyncOperation::IDEMPOTENCY_KEY_FORMAT)

      raise Error::Validation.new(
              "Idempotency-Key must be a UUID and is required for #{entity_label} POST requests.",
              code: "idempotency_key_invalid",
              http_status: :unprocessable_entity
            )
    end

    def raise_key_conflict!
      raise_conflict!(
        "This idempotency key was already used with different #{entity_label} data or for another operation.",
        "idempotency_key_reused"
      )
    end

    def raise_conflict!(message, code)
      raise Error::Conflict.new(message, code: code, http_status: :conflict)
    end
  end
end
