open Tc;

module Styles = {
  open Css;

  let sidebar =
    style([
      width(`rem(14.)),
      overflow(`hidden),
      display(`flex),
      flexDirection(`column),
      justifyContent(`spaceBetween),
      borderRight(`px(1), `solid, Theme.Colors.borderColor),
    ]);

  let footer = style([padding2(~v=`rem(0.5), ~h=`rem(1.))]);
};

module Wallets = [%graphql
  {| query getWallets { wallets {publicKey, balance {total}} } |}
];
module WalletQuery = ReasonApollo.CreateQuery(Wallets);

module AddWallet = [%graphql
  {|
  mutation {
      addWallet(input: {}) {
          publicKey
      }
  }
|}
];

module AddWalletMutation = ReasonApollo.CreateMutation(AddWallet);

[@react.component]
let make = () => {
  let (modalState, setModalState) = React.useState(() => None);
  let (_settings, updateSettings) =
    React.useContext(SettingsProvider.context);

  <div className=Styles.sidebar>
    <WalletQuery>
      {response =>
         switch (response.result) {
         | Loading => React.string("...")
         | Error(err) => React.string(err##message)
         | Data(data) =>
           <WalletList
             wallets={Array.map(~f=Wallet.ofGraphqlExn, data##wallets)}
           />
         }}
    </WalletQuery>
    <div className=Styles.footer>
      <Link onClick={_ => setModalState(_ => Some("My Wallet"))}>
        {React.string("+ Add wallet")}
      </Link>
    </div>
    <AddWalletMutation>
      {(mutation, _) =>
         switch (modalState) {
         | None => React.null
         | Some(newWalletName) =>
           <AddWalletModal
             walletName=newWalletName
             setModalState
             onSubmit={name => {
               let performMutation =
                 Task.liftPromise(() =>
                   mutation(~refetchQueries=[|"getWallets"|], ())
                 );
               Task.perform(
                 performMutation,
                 ~f=
                   fun
                   | EmptyResponse => ()
                   | Errors(_) => print_endline("Error adding wallet")
                   | Data(data) =>
                     data##addWallet
                     |> Option.andThen(~f=addWallet => addWallet##publicKey)
                     |> Option.map(~f=pk => {
                          let key = PublicKey.ofStringExn(pk);
                          updateSettings(
                            Option.map(~f=Settings.set(~key, ~name)),
                          );
                        })
                     |> ignore,
               );
             }}
           />
         }}
    </AddWalletMutation>
  </div>;
};
