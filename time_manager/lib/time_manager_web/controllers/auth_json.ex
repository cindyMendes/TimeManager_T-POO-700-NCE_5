defmodule TimeManagerWeb.AuthJSON do
  alias TimeManager.Accounts.User

  def user(%{user: user}) do
    %{data: user_json(user)}
  end

  def login(%{user: user, token: token}) do
    %{
      data: %{
        user: user_json(user),
        token: token
      }
    }
  end

  def error(%{message: message}) do
    %{error: message}
  end

  defp user_json(%User{} = user) do
    %{
      id: user.id,
      email: user.email
    }
  end
end