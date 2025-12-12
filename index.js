import React, { forwardRef } from 'react';
import { requireNativeComponent } from 'react-native';

const NativeRNKLineView = requireNativeComponent('RNKLineView');

/**
 * Wrapper around the native `RNKLineView`.
 *
 * - `onNewOrder(price)` is normalized to pass only the hovered price number.
 *   Native event shape: { nativeEvent: { price: number } }
 */
const RNKLineView = forwardRef((props, ref) => {
  const { onNewOrder, ...rest } = props;
  const handleNewOrder = onNewOrder
    ? e => onNewOrder?.(e?.nativeEvent?.price)
    : undefined;
  return <NativeRNKLineView ref={ref} {...rest} onNewOrder={handleNewOrder} />;
});

RNKLineView.displayName = 'RNKLineView';

export default RNKLineView;
