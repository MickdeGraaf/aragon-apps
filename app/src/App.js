import React from 'react'
import PropTypes from 'prop-types'
import BN from 'bn.js'
import { Badge, Main, SidePanel } from '@aragon/ui'
import { useAragonApi } from '@aragon/api-react'
import EmptyState from './screens/EmptyState'
import Holders from './screens/Holders'
import AssignVotePanelContent from './components/Panels/AssignVotePanelContent'
import AssignTokensIcon from './components/AssignTokensIcon'
import AppLayout from './components/AppLayout'
import { addressesEqual } from './web3-utils'
import { IdentityProvider } from './components/IdentityManager/IdentityManager'

const initialAssignTokensConfig = {
  mode: null,
  holderAddress: '',
}

class App extends React.PureComponent {
  static propTypes = {
    api: PropTypes.object,
  }
  static defaultProps = {
    appStateReady: false,
    holders: [],
    connectedAccount: '',
    groupMode: false,
  }
  state = {
    assignTokensConfig: initialAssignTokensConfig,
    sidepanelOpened: false,
  }
  getHolderBalance = address => {
    const { holders } = this.props
    const holder = holders.find(holder =>
      addressesEqual(holder.address, address)
    )
    return holder ? holder.balance : new BN('0')
  }
  handleUpdateTokens = ({ amount, holder, mode }) => {
    const { api } = this.props

    if (mode === 'assign') {
      api.mint(holder, amount)
    }
    if (mode === 'remove') {
      api.burn(holder, amount)
    }

    this.handleSidepanelClose()
  }
  handleLaunchAssignTokensNoHolder = () => {
    this.handleLaunchAssignTokens('')
  }
  handleLaunchAssignTokens = address => {
    this.setState({
      assignTokensConfig: { mode: 'assign', holderAddress: address },
      sidepanelOpened: true,
    })
  }
  handleLaunchRemoveTokens = address => {
    this.setState({
      assignTokensConfig: { mode: 'remove', holderAddress: address },
      sidepanelOpened: true,
    })
  }
  handleSidepanelClose = () => {
    this.setState({ sidepanelOpened: false })
  }
  handleSidepanelTransitionEnd = open => {
    if (!open) {
      this.setState({ assignTokensConfig: initialAssignTokensConfig })
    }
  }
  handleResolveLocalIdentity = address => {
    return this.props.api.resolveAddressIdentity(address).toPromise()
  }
  handleShowLocalIdentityModal = address => {
    return this.props.api
      .requestAddressIdentityModification(address)
      .toPromise()
  }
  render() {
    const {
      appStateReady,
      groupMode,
      holders,
      maxAccountTokens,
      numData,
      tokenAddress,
      tokenDecimalsBase,
      tokenName,
      tokenSupply,
      tokenSymbol,
      tokenTransfersEnabled,
      connectedAccount,
      requestMenu,
    } = this.props
    const { assignTokensConfig, sidepanelOpened } = this.state
    return (
      <Main assetsUrl="./aragon-ui">
        <div css="min-width: 320px">
          <IdentityProvider
            onResolve={this.handleResolveLocalIdentity}
            onShowLocalIdentityModal={this.handleShowLocalIdentityModal}
          >
            <AppLayout
              title="Token Manager"
              afterTitle={tokenSymbol && <Badge.App>{tokenSymbol}</Badge.App>}
              onMenuOpen={requestMenu}
              mainButton={{
                label: 'Assign tokens',
                icon: <AssignTokensIcon />,
                onClick: this.handleLaunchAssignTokensNoHolder,
              }}
              smallViewPadding={0}
            >
              {appStateReady && holders.length > 0 ? (
                <Holders
                  holders={holders}
                  groupMode={groupMode}
                  maxAccountTokens={maxAccountTokens}
                  tokenAddress={tokenAddress}
                  tokenDecimalsBase={tokenDecimalsBase}
                  tokenName={tokenName}
                  tokenSupply={tokenSupply}
                  tokenSymbol={tokenSymbol}
                  tokenTransfersEnabled={tokenTransfersEnabled}
                  userAccount={connectedAccount}
                  onAssignTokens={this.handleLaunchAssignTokens}
                  onRemoveTokens={this.handleLaunchRemoveTokens}
                />
              ) : (
                <EmptyState
                  onActivate={this.handleLaunchAssignTokensNoHolder}
                />
              )}
            </AppLayout>
            <SidePanel
              title={
                assignTokensConfig.mode === 'assign'
                  ? 'Assign tokens'
                  : 'Remove tokens'
              }
              opened={sidepanelOpened}
              onClose={this.handleSidepanelClose}
              onTransitionEnd={this.handleSidepanelTransitionEnd}
            >
              {appStateReady && (
                <AssignVotePanelContent
                  opened={sidepanelOpened}
                  tokenDecimals={numData.tokenDecimals}
                  tokenDecimalsBase={tokenDecimalsBase}
                  onUpdateTokens={this.handleUpdateTokens}
                  getHolderBalance={this.getHolderBalance}
                  maxAccountTokens={maxAccountTokens}
                  {...assignTokensConfig}
                />
              )}
            </SidePanel>
          </IdentityProvider>
        </div>
      </Main>
    )
  }
}

export default () => {
  const { api, appState, connectedAccount, requestMenu } = useAragonApi()
  return (
    <App
      api={api}
      connectedAccount={connectedAccount}
      requestMenu={requestMenu}
      {...appState}
    />
  )
}
