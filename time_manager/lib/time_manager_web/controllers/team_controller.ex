defmodule TimeManagerWeb.TeamController do
  use TimeManagerWeb, :controller

  alias TimeManager.Teams
  alias TimeManager.Teams.Team
  alias TimeManager.Accounts

  # Existing index function remains the same
  def index(conn, _params) do
    teams = Teams.list_teams()

    conn
    |> put_status(:ok)
    |> json(%{
      data: Enum.map(teams, fn team ->
        %{
          id: team.id,
          name: team.name,
          manager: %{
            id: team.manager.id,
            username: team.manager.username,
            email: team.manager.email,
            role: team.manager.role,
            inserted_at: team.manager.inserted_at,
            updated_at: team.manager.updated_at
          },
          members: Enum.map(team.members, fn member ->
            %{
              id: member.id,
              username: member.username,
              email: member.email,
              role: member.role,
              inserted_at: member.inserted_at,
              updated_at: member.updated_at
            }
          end),
          inserted_at: team.inserted_at,
          updated_at: team.updated_at
        }
      end)
    })
  end

  def create(conn, %{"team" => team_params}) do
    with {:ok, %Team{} = team} <- Teams.create_team(team_params) do
      conn
      |> put_status(:created)
      |> render("show.json", team: team)
    end
  end

  def update(conn, %{"id" => id, "team" => team_params}) do
    team = Teams.get_team!(id)

    with {:ok, %Team{} = team} <- Teams.update_team(team, team_params) do
      render(conn, "show.json", team: team)
    end
  end

  def delete(conn, %{"id" => id}) do
    IO.inspect(id, label: "Attempting to delete team")

    # First check if team exists and get its members
    team = Teams.get_team_with_members!(id)

    # Check if team has members
    if length(team.members) > 0 do
      IO.inspect(team.members, label: "Team still has members")
      conn
      |> put_status(:unprocessable_entity)
      |> json(%{
        errors: ["Cannot delete team with existing members. Please remove all members first."]
      })
    else
      case Teams.delete_team(team) do
        {:ok, _deleted_team} ->
          conn
          |> put_status(:ok)
          |> json(%{
            data: %{
              message: "Team successfully deleted",
              id: id
            }
          })

        {:error, changeset} ->
          IO.inspect(changeset, label: "Delete team error")
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{
            errors: Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
              Enum.reduce(opts, msg, fn {key, value}, acc ->
                String.replace(acc, "%{#{key}}", to_string(value))
              end)
            end)
          })
      end
    end
  rescue
    e in Ecto.NoResultsError ->
      IO.inspect(e, label: "Team not found")
      conn
      |> put_status(:not_found)
      |> json(%{errors: ["Team not found"]})

    e in _ ->
      IO.inspect(e, label: "Unexpected error during team deletion")
      conn
      |> put_status(:internal_server_error)
      |> json(%{errors: ["An unexpected error occurred while deleting the team"]})
  end

  def show(conn, %{"id" => id}) do
    team = Teams.get_team_with_members!(id)
    render(conn, "show_with_members.json", team: team)
  end

  def add_user_to_team(conn, %{"team_id" => team_id, "user_id" => user_id}) do
    IO.inspect(%{team_id: team_id, user_id: user_id}, label: "Received Parameters")

    # Get and inspect user and team
    user = Accounts.get_user!(user_id)
    team = Teams.get_team!(team_id)

    IO.inspect(user, label: "User to update")
    IO.inspect(team, label: "Target team")

    # Create update params while preserving all required user data
    update_params = %{
      "team_id" => team_id,
      "username" => user.username,
      "email" => user.email,
      "role" => user.role
    }

    IO.inspect(update_params, label: "Update Parameters")

    # Attempt to update with more detailed error handling
    case Accounts.update_user(user, update_params) do
      {:ok, updated_user} ->
        IO.inspect(updated_user, label: "Successfully Updated User")
        conn
        |> put_status(:ok)
        |> json(%{
          data: %{
            message: "User successfully added to team",
            user: %{
              id: updated_user.id,
              username: updated_user.username,
              email: updated_user.email,
              role: updated_user.role,
              team_id: updated_user.team_id,
              inserted_at: updated_user.inserted_at,
              updated_at: updated_user.updated_at
            }
          }
        })

      {:error, %Ecto.Changeset{} = changeset} ->
        IO.inspect(changeset.errors, label: "Validation Errors")
        IO.inspect(changeset.valid?, label: "Changeset Valid?")
        IO.inspect(changeset.changes, label: "Attempted Changes")

        error_messages = Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
          Enum.reduce(opts, msg, fn {key, value}, acc ->
            String.replace(acc, "%{#{key}}", to_string(value))
          end)
        end)

        IO.inspect(error_messages, label: "Formatted Error Messages")

        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          errors: error_messages,
          details: "Failed to add user to team. Please check the error messages."
        })

      {:error, other_error} ->
        IO.inspect(other_error, label: "Unexpected Error")
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          errors: ["An unexpected error occurred while updating the user"],
          details: inspect(other_error)
        })
    end
  rescue
    e in Ecto.NoResultsError ->
      IO.inspect(e, label: "Not Found Error")
      conn
      |> put_status(:not_found)
      |> json(%{errors: ["User or team not found"]})

    e in _ ->
      IO.inspect(e, label: "Unexpected Exception")
      conn
      |> put_status(:internal_server_error)
      |> json(%{errors: ["An unexpected error occurred"]})
  end

  def remove_member(conn, %{"id" => team_id, "user_id" => user_id}) do
    IO.inspect(%{team_id: team_id, user_id: user_id}, label: "Remove member parameters")

    # Get user and team
    user = Accounts.get_user!(user_id)
    team = Teams.get_team!(team_id)

    # Verify user belongs to this team
    if user.team_id != team.id do
      conn
      |> put_status(:unprocessable_entity)
      |> json(%{errors: ["User is not a member of this team"]})
    else
      # Create update params while preserving required fields
      update_params = %{
        "team_id" => nil,
        "username" => user.username,
        "email" => user.email,
        "role" => user.role
      }

      IO.inspect(update_params, label: "Remove member update params")

      case Accounts.update_user(user, update_params) do
        {:ok, updated_user} ->
          IO.inspect(updated_user, label: "Successfully removed member")
          conn
          |> put_status(:ok)
          |> json(%{
            data: %{
              message: "Member successfully removed from the team",
              user: %{
                id: updated_user.id,
                username: updated_user.username,
                email: updated_user.email,
                role: updated_user.role,
                team_id: updated_user.team_id,
                inserted_at: updated_user.inserted_at,
                updated_at: updated_user.updated_at
              }
            }
          })

        {:error, changeset} ->
          IO.inspect(changeset, label: "Remove member error")
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{
            errors: Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
              Enum.reduce(opts, msg, fn {key, value}, acc ->
                String.replace(acc, "%{#{key}}", to_string(value))
              end)
            end)
          })
      end
    end
  rescue
    e in Ecto.NoResultsError ->
      IO.inspect(e, label: "User or team not found")
      conn
      |> put_status(:not_found)
      |> json(%{errors: ["User or team not found"]})

    e in _ ->
      IO.inspect(e, label: "Unexpected error during member removal")
      conn
      |> put_status(:internal_server_error)
      |> json(%{errors: ["An unexpected error occurred while removing the member"]})
  end
end
