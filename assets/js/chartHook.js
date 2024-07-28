import "../vendor/lightweightCharts";

export const StockChart = {
  mounted() {
    const chart = window.LightweightCharts.createChart(this.el, {
      width: window.innerWidth * 0.6,
      height: window.innerHeight * 0.4,
      rightPriceScale: {
        visible: true,
      },
      leftPriceScale: {
        visible: true,
      },
    });
    const btc = chart.addLineSeries({ priceScaleId: "right" });

    chart.timeScale().fitContent();

    this.handleEvent("new", ({ value }) => {
      const newPriceEvt = {
        time: new Date().getTime() / 1000,
        value: Number(value),
      };
      btc.update(newPriceEvt);
    });

    window.addEventListener("resize", () => {
      chart.resize(window.innerWidth * 0.6, window.innerHeight * 0.4);
    });
  },
};
