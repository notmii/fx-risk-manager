#property copyright "notmii"
#property link      "https://github.com/notmii/risk-manager-ea"
#property version   "1.00"
#property strict

#include <mt4gui2.mqh>

// RISK MANAGEMENT VARIABLES
input int RISK_PIPS = 30;
input double RISK_BALANCE_PERCENT = 2,
  WIN_LOSS_RATIO = 3;

input int X_POSITION = 0;

int hwnd = 0,
  buyButton = 0,
  sellButton = 0,
  closeButton = 0,
  riskBalancePercentTextbox = 0,
  riskPipsTextbox = 0,
  winLossRatioTextbox = 0;

double lots,
  riskPips,
  riskBalancePercent,
  riskValue,
  winLossRatio;

int OnInit()
{
  hwnd = WindowHandle(Symbol(), Period());
  // guiVendor("259495BDD3F940996B5FF5475EB0BFFE");
  guiRemoveAll(hwnd);
  buyButton = guiAdd(hwnd,"button",5 + X_POSITION,30,50,30,"Buy");
  sellButton = guiAdd(hwnd,"button",55 + X_POSITION,30,50,30,"Sell");
  closeButton = guiAdd(hwnd,"button",105 + X_POSITION,30,50,30,"Close");
  riskBalancePercentTextbox = guiAdd(hwnd,"text",5 + X_POSITION,60,50,30,DoubleToString(RISK_BALANCE_PERCENT, 1));
  riskPipsTextbox = guiAdd(hwnd,"text",55 + X_POSITION,60,50,30,IntegerToString(RISK_PIPS, 2));
  winLossRatioTextbox = guiAdd(hwnd,"text",105 + X_POSITION,60,50,30,DoubleToString(WIN_LOSS_RATIO, 1));
  
  computeLots();
  displayValues();
  return(INIT_SUCCEEDED);
}

int OnDeinit()
{
  if (hwnd > 0) {
    guiRemoveAll(hwnd);
    guiCleanup(hwnd);
  }
  return(0);
}

void OnTick()
{
  displayValues();
  if (guiIsClicked(hwnd, closeButton)) {
  }

  double stopLoss, takeProfit;
  bool isBuyClicked = guiIsClicked(hwnd, buyButton);
  bool isSellClicked = guiIsClicked(hwnd, sellButton);
  
  if (!isInputsValid()) {
    Print("Invalid inputs");
    return;
  }
  
  winLossRatio = StrToDouble(guiGetText(hwnd, winLossRatioTextbox));
  computeLots();
  breakEven();
  
  if (OrdersTotal() > 0) {
    ObjectDelete("BuyResistance");
    ObjectDelete("BuySupport");
    ObjectDelete("SellResistance");
    ObjectDelete("SellSupport");
  }
      
  stopLoss = Ask - (Point * riskPips);
  takeProfit = Ask + (Point * winLossRatio * riskPips);
  if (OrdersTotal() == 0 ) drawBuyOrders(stopLoss, takeProfit);
  
  if (isBuyClicked && lots > 0) {
    OrderSend(NULL, OP_BUY, lots, Ask, 2, stopLoss, takeProfit, "Buy", 0, 0, Green);
  }
    
  stopLoss = Bid + (Point * riskPips);
  takeProfit = Bid - (Point * winLossRatio * riskPips);
  if (OrdersTotal() == 0 ) drawSellOrders(stopLoss, takeProfit);
  
  if (isSellClicked && lots > 0) {
    OrderSend(NULL, OP_SELL, lots, Bid, 2, stopLoss, takeProfit, "Sell", 0, 0, Red);
  }
  
  displayValues();
}

void displayValues()
{  
  Comment(
    "\n\n\n\n\n\n",
    "\n    Balance: ", DoubleToStr(AccountBalance(), 2),
    "\n    Equity: ", DoubleToStr(AccountEquity(), 2),
    "\n    Margin: ", AccountMargin(),
    "\n    Free Margin: ", DoubleToStr(AccountFreeMargin(), 2),
    "\n    Margin Level: ", AccountEquity() > 0 && AccountMargin() > 0 ?
        (int)((AccountEquity() / AccountMargin()) * 100) : "", "%",
    "\n    Leverage: 1:", AccountLeverage(),
    "\n    Spread: ", (int)((Ask - Bid) / Point),
    "\n",
    "\n    Risk Balance: ", DoubleToStr(riskValue, 2), " (", DoubleToStr(riskBalancePercent, 2), "%)",
    "\n    Risk Pips: ", DoubleToStr(riskPips, 2),
    "\n    W/L Ratio: ", DoubleToStr(winLossRatio, 1), ":1",
    ""
  );
}

bool isInputsValid()
{
  return StrToDouble(guiGetText(hwnd, riskPipsTextbox)) > 0
    && StrToDouble(guiGetText(hwnd, riskBalancePercentTextbox)) > 0
    && StrToDouble(guiGetText(hwnd, winLossRatioTextbox)) > 0;
}

void computeLots()
{
  riskPips = StrToInteger(guiGetText(hwnd, riskPipsTextbox));
  riskBalancePercent = StrToDouble(guiGetText(hwnd, riskBalancePercentTextbox));
  riskValue = AccountBalance() * (riskBalancePercent / 100);
  lots = (riskValue / (riskPips * Point)) / 100000;
  lots = MathFloor(lots * 100) / 100;
}

void breakEven()
{
  if (OrdersTotal() <= 0) {
    return;
  }
  
  if (OrderSelect(0, SELECT_BY_POS, MODE_TRADES) < 0) {
    return;
  }
  
  if (OrderType() == OP_BUY) {
    double difference = Close[0] - OrderOpenPrice();
    if (difference >= (Point * riskPips * winLossRatio)) {
      OrderModify(OrderTicket(), OrderOpenPrice(), OrderOpenPrice(), OrderTakeProfit(), 0);
    }
    return;
  }
  
  if (OrderType() == OP_SELL) {
    double difference =  OrderOpenPrice() - Close[0];
    if (difference >= (Point * riskPips * winLossRatio)) {
      OrderModify(OrderTicket(), OrderOpenPrice(), OrderOpenPrice(), OrderTakeProfit(), 0);
    }
    return;
  }
}

void drawBuyOrders(double stopLoss, double takeProfit)
{
  if (ObjectFind("BuyResistance") <= 0) {
      ObjectCreate("BuyResistance", OBJ_HLINE, 0, 0, takeProfit);
      ObjectSet("BuyResistance", OBJPROP_COLOR, Green);
      ObjectSet("BuyResistance", OBJPROP_STYLE, STYLE_DASH);
  }
  
  if (ObjectFind("BuySupport") <= 0) {
      ObjectCreate("BuySupport", OBJ_HLINE, 0, 0, stopLoss);
      ObjectSet("BuySupport", OBJPROP_COLOR, Green);
      ObjectSet("BuySupport", OBJPROP_STYLE, STYLE_DASH);
  }
  
  ObjectMove("BuyResistance", 0, 0, takeProfit);
  ObjectMove("BuySupport", 0, 0, stopLoss);
}

void drawSellOrders(double stopLoss, double takeProfit)
{
  if (ObjectFind("SellResistance") <= 0) {
      ObjectCreate("SellResistance", OBJ_HLINE, 0, 0, takeProfit);
      ObjectSet("SellResistance", OBJPROP_COLOR, Red);
      ObjectSet("SellResistance", OBJPROP_STYLE, STYLE_DASH);
  }
  
  if (ObjectFind("SellSupport") <= 0) {
      ObjectCreate("SellSupport", OBJ_HLINE, 0, 0, stopLoss);
      ObjectSet("SellSupport", OBJPROP_COLOR, Red);
      ObjectSet("SellSupport", OBJPROP_STYLE, STYLE_DASH);
  }
  
  ObjectMove("SellResistance", 0, 0, takeProfit);
  ObjectMove("SellSupport", 0, 0, stopLoss);
}
