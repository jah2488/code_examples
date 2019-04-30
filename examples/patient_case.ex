defmodule Resources.Patient.Document.PatientCase do
  @behaviour RemoteResource
  @moduledoc """
  patient case
  """

  defstruct [
    :patientcaseid,
    :callbackname,
    :callbacknumber,
    :departmentid,
    :documentsource,
    :documentsubclass,
    :internalnote,
    :providerid,
    :subject,
    :patientid
  ]
  use ExConstructor

  alias Resources.Patient.Document.PatientCase.Source
  alias Resources.Patient.Document.PatientCase.Subclass

  import RemoteResource, only: [get_key_from_value: 2]
  import Utilities.Transformers,
    only: [transforms_phone_number_to: 1, transforms_phone_number_from: 1]

  def attribute_mapping do
    %{
      :id                     => :patientcaseid,
      :subject                => :subject,
      :body                   => :internalnote,
      :location_id            => :departmentid,
      :recipient_id           => :providerid,
      :patient_id             => :patientid,
      :source                 => :documentsource,
      :type                   => :documentsubclass,
      :callback_name          => :callbackname,
      :callback_phone_number  => :callbacknumber,
    }
  end

  def transforms_from do
    %{
      :source   =>  fn(val) -> Source.mapping() |> get_key_from_value(val) end,
      :type     =>  fn(val) -> Subclass.mapping() |> get_key_from_value(val) end,
      :callback_phone_number => &transforms_phone_number_from/1
     }
  end

  def transforms_to do
    %{
      :source   => fn(source_id) -> Map.fetch!(Source.mapping(), source_id) end,
      :type     => fn(type_id)   -> Map.fetch!(Subclass.mapping(), type_id) end,
      :callback_phone_number => &transforms_phone_number_to/1
    }
  end
end
