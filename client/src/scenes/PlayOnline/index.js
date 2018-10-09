import React, { PureComponent } from "react";
import classnames from "classnames";
import Notif from "../../components/Notif";
import {
  InputGroup,
  InputGroupAddon,
  Input,
  InputGroupText,
  Button,
  Collapse,
  TabContent,
  TabPane,
  Nav,
  NavItem,
  NavLink,
  Row,
  Col,
  Modal,
  ModalBody,
  ModalHeader,
  ModalFooter,
  Dropdown,
  DropdownToggle,
  DropdownMenu,
  DropdownItem
} from "reactstrap";
import RoundTicketList from "./components/RoundTicketList";
import OwnerTicketList from "./components/OwnerTicketList/index";
import OldWinners from "./components/OldWinners";
import { connect } from "react-redux";
import ChanceRateReport from "./components/ChanceRateReport";

class PlayOnline extends PureComponent {
  state = {
    activeTab: "1",
    nextTab: null,
    // modal: false,
    infoModal: false,
    connected: this.props.account ? true : false,
    ticketNumber: 1,
    gas: 7000000,
    dropdownOpen: false,
    keyInputOpened: false,
    privateKey: ""
  };

  componentWillReceiveProps(nextProps) {
    const { dispatch } = this.props;
    if (nextProps.account && nextProps.account !== this.props.account) {
      this.setState({ connected: true });
      // turn off modal once account is received after 'PL_JOIN_REQUESTED'
      dispatch({ type: "PL_TOGGLE_MODAL" });
    }
  }

  componentDidUpdate() {
    const { account } = this.props;
    const { nextTab } = this.state;
    if (account && nextTab) {
      this.setState({
        nextTab: null
      });
      this.toggle(nextTab);
    }
  }

  toggle = tab => {
    if (this.state.activeTab !== tab) {
      if (tab === "2") {
        if (this.props.account) {
          this.setState({
            activeTab: tab
          });
        } else {
          this.setState({
            nextTab: tab
          });
          this.toggleModal();
        }
      } else {
        this.setState({
          activeTab: tab
        });
      }
    }
  };

  toggleModal = () => {
    const { dispatch } = this.props;
    this.setState({
      privateKey: "",
      keyInputOpened: false,
      // modal: !this.state.modal
    });
    dispatch({ type: "PL_TOGGLE_MODAL" });
  };

  toggleInfoModal = () => {
    const { infoModal } = this.state;
    const estimatedGas = this.props.estimatedGas || this.state.gas;
    this.setState({
      infoModal: !infoModal,
      gas: estimatedGas,
    })
  }

  connectAccount = (type) => {
    const { dispatch } = this.props;
    if (type === 'meta') {
      dispatch({ type: "PL_JOIN_REQUESTED" });
      this.setState({
        keyInputOpened: false
      });
    }
    if (type === 'private') {
      // show the Collapse component to let user type in private key
      this.setState({
        keyInputOpened: !this.state.keyInputOpened
      })
    }
  };

  onPrivateKeyInputChange = (event) => {
    this.setState({
      privateKey: event.target.value
    })
  }

  onPrivateKeyButtonClick = () => {
    const { dispatch } = this.props;
    if (this.state.privateKey) {
      dispatch({ type: "PL_JOIN_REQUESTED", payload: this.state.privateKey });
    }
    else {
      Notif.error('Please input private key')
    }
  }

  onBuyClick = () => {
    const { connected } = this.state;
    const { connectType } = this.props;
    if (connected) {
      if (connectType === 0) {
        // if user is using metamask, then skip the Info modal
        this.dispatchBuyAction(true);
      } else {
        // show modal to allow input GAS if user is using private key
        this.toggleInfoModal();
      }
    } else {
      this.toggleModal();
    }
  };

  dispatchBuyAction = (wontToggle) => {
    const { dispatch, ticketPrice } = this.props; 
    const { gas, ticketNumber } = this.state;
    const totalCost = ticketNumber * ticketPrice;
    dispatch({ type: "PL_TICKETS_BUY_REQUESTED", payload: {
      totalCost: totalCost,
      gas: gas,
    } });
    if(!wontToggle) this.toggleInfoModal();
  }

  onTicketNumberChange = e => {
    const { ticketNumber } = this.state;
    if (e.target.value !== undefined && e.target.value !== ticketNumber) {
      this.setState({ ticketNumber: e.target.value });
    }
  };

  onGasChange = e => {
    const { gas } = this.state;
    if (e.target.value !== undefined && e.target.value !== gas) {
      this.setState({ gas: e.target.value });
    }
  }

  toggleDropdown = () => {
    this.setState(prevState => ({
      dropdownOpen: !prevState.dropdownOpen
    }));
  };

  render() {
    const { ticketNumber, dropdownOpen, gas, infoModal } = this.state;
    const { ticketPrice, modal } = this.props;
    const totalCost = ticketNumber * ticketPrice;

    return (
      <div className="play-online">
        <div className="container">
          <div className="row">
            <div className="col-md-6 wow fadeInLeft">
              <div className="row row-playonline justify-content-center">
                <InputGroup>
                  <InputGroupAddon addonType="prepend">
                    <InputGroupText>Quantity</InputGroupText>
                  </InputGroupAddon>
                  <Input
                    className="text-center"
                    placeholder="1000 Tickets"
                    type="number"
                    min={1}
                    value={ticketNumber}
                    onChange={this.onTicketNumberChange}
                  />
                  <InputGroupAddon addonType="append">
                    <InputGroupText>
                      Cost:
                      {/* Dropdown select ETH or ERC20 token */}
                      <Dropdown
                        isOpen={dropdownOpen}
                        toggle={this.toggleDropdown}
                      >
                        <DropdownToggle caret color="paymentmethod">
                          {(ticketPrice * ticketNumber).toFixed(3)} ETH
                        </DropdownToggle>
                        <DropdownMenu>
                          <DropdownItem>
                            {(ticketPrice * ticketNumber).toFixed(3)} ETH
                          </DropdownItem>
                          <DropdownItem>
                            {(ticketPrice * ticketNumber).toFixed(3)} GEX
                          </DropdownItem>
                          <DropdownItem>
                            {(ticketPrice * ticketNumber).toFixed(3)} BNB
                          </DropdownItem>
                        </DropdownMenu>
                      </Dropdown>
                    </InputGroupText>
                  </InputGroupAddon>
                </InputGroup>
                <Button color="primary" onClick={this.onBuyClick}>
                  Buy Now
                </Button>
              </div>
              <ChanceRateReport /><Row className="nextdrawtime">
                <Col xs={12} className="text-center">
                  <strong>Next Draw Timestamp</strong>
                  <p>Friday, October 5, 2018 12:00:00 AM (GMT)</p>
                </Col>
                <Col xs={6} md={6}>
                  <strong>Total tickets (of all players)</strong>
                  <p>1,000,000 Tickets</p>
                </Col>
                <Col xs={6} md={6}>
                  <strong>Price Per Ticket</strong>
                  <p>0,0001 ETH</p>
                </Col>
              </Row>
              <Row className="totalpotamount text-center justify-content-center">
                <Row>
                  <Col>
                    <strong>Total amount (ETH and all ERC20 Token)</strong>
                    <p>100.001 ETH</p>
                  </Col>
                </Row>
                <Row>
                  <Col xs={6} md={6}>
                    <strong>ETH amount</strong>
                    <p>100.001 ETH</p>
                  </Col>
                  <Col xs={6} md={6}>
                    <strong>GreenX amount</strong>
                    <p>100.001 GEX</p>
                  </Col>
                  <Col xs={6} md={6}>
                    <strong>Binance amount</strong>
                    <p>100.001 BNB</p>
                  </Col>
                  <Col xs={6} md={6}>
                    <strong>HKK Token amount</strong>
                    <p>100.001 HKK</p>
                  </Col>
                </Row>
              </Row>
              {/* <Row className="row-howitwork">
                <Col>
                  <h3>How it work?</h3>
                  <p>
                    What is this game? This game is called lottery. You can buy
                    lottery tickets and hope that one of your ticket numbers
                    will be picked. The draw takes place once per week, on
                    Thursday. How to play Click on tab "Buy ticket" and enter
                    number of tickets you want to buy. Each ticket costs
                    <strong>{` ${ticketPrice} `}</strong>
                    ETH. You can buy tickets only with Ether. Lots will be drawn
                    each week on thursday using random numbers generated through
                  </p>
                </Col>
              </Row> */}
            </div>
            <div className="col-md-6 wow fadeInRight">
              <Nav tabs>
                <NavItem>
                  <NavLink
                    className={classnames({
                      active: this.state.activeTab === "1"
                    })}
                    onClick={() => {
                      this.toggle("1");
                    }}
                  >
                    This round tickets
                  </NavLink>
                </NavItem>
                <NavItem>
                  <NavLink
                    className={classnames({
                      active: this.state.activeTab === "2"
                    })}
                    onClick={() => {
                      this.toggle("2");
                    }}
                  >
                    Your tickets
                  </NavLink>
                </NavItem>
                <NavItem>
                  <NavLink
                    className={classnames({
                      active: this.state.activeTab === "3"
                    })}
                    onClick={() => {
                      this.toggle("3");
                    }}
                  >
                    Winner List
                  </NavLink>
                </NavItem>
              </Nav>
              <TabContent activeTab={this.state.activeTab}>
                <TabPane tabId="1">
                  <RoundTicketList />
                </TabPane>
                <TabPane tabId="2">
                  <OwnerTicketList />
                </TabPane>
                <TabPane tabId="3">
                  <OldWinners />
                </TabPane>
              </TabContent>
            </div>
          </div>
          <Modal
            isOpen={modal}
            toggle={this.toggleModal}
            className={this.props.className}
          >
            <ModalHeader className="text-center" toggle={this.toggleModal}>
              Connect to your wallet through
            </ModalHeader>
            <ModalBody className="text-center">
              Connecting to Wallet is required to use this function.
              <p />
              <Row className="justify-content-center">
                <Col xs={4} md={3}>
                  <Button color="" onClick={() => {
                    this.connectAccount('meta')
                  }}>
                    <img src="/img/metamask.svg" style={{ height: 48 }} />
                    <p>Metamask</p>
                  </Button>
                </Col>
                <Col xs={4} md={3}>
                  <Button color="" onClick={() => {
                    this.connectAccount('private')
                  }}>
                    <img src="/img/private-key.svg" style={{ height: 48 }} />
                    <p>Private Key</p>
                  </Button>
                </Col>
              </Row>
              <p />
            </ModalBody>
            <ModalFooter>
              <Collapse style={{width: "100%"}} isOpen={this.state.keyInputOpened}>
                <Row>
                  <Col xs={8} md={9}>
                    <Input type="password" placeholder="Enter Private Key" onChange={this.onPrivateKeyInputChange} />
                  </Col>
                  <Col xs={3} md={2}>
                    <Button color="primary" onClick={this.onPrivateKeyButtonClick}>
                      Connect!
                    </Button>
                  </Col>
                </Row>
              </Collapse>
            </ModalFooter>
          </Modal>
          <Modal
            isOpen={infoModal}
            toggle={this.toggleInfoModal}
            className={this.props.className}
          >
            <ModalBody>
              <InputGroup>
                <InputGroupAddon addonType="prepend">
                  <InputGroupText>Cost</InputGroupText>
                </InputGroupAddon>
                <Input
                  disabled={true}
                  className="text-center"
                  placeholder={totalCost}>
                </Input>
              </InputGroup>
              <InputGroup>
                <InputGroupAddon addonType="prepend">
                  <InputGroupText>Gas </InputGroupText>
                </InputGroupAddon>
                <Input
                    className="text-center"
                    placeholder="Gas"
                    type="number"
                    min={21000}
                    value={gas}
                    onChange={this.onGasChange}
                />
              </InputGroup>
            </ModalBody>
            <ModalFooter>
              <Button color="primary" onClick={this.dispatchBuyAction}>Buy Tickets!</Button>
            </ModalFooter>
          </Modal>
        </div>
      </div>
    );
  }
}

const mapStateToProps = ({ global, player }) => ({
  account: player.account,
  modal: player.modal,
  connectType: player.connectType,
  estimatedGas: player.estimatedGas,
  ticketPrice: global.ticketPrice ? global.ticketPrice : NaN
});

export default connect(mapStateToProps)(PlayOnline);
