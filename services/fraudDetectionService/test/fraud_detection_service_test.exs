defmodule FraudDetectionServiceTest do
  use ExUnit.Case
  doctest FraudDetectionService

  test "greets the world" do
    assert FraudDetectionService.hello() == :world
  end
end
