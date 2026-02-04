Mox.defmock(PrzetargowyPrzeglad.Stripe.ClientMock, for: PrzetargowyPrzeglad.Stripe.ClientBehaviour)

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(PrzetargowyPrzeglad.Repo, :manual)

# Set up global stubs after ExUnit starts
Mox.set_mox_global()
Mox.stub_with(PrzetargowyPrzeglad.Stripe.ClientMock, PrzetargowyPrzeglad.Stripe.ClientStub)
