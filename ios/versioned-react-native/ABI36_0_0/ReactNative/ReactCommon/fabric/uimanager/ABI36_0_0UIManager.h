// Copyright 2004-present Facebook. All Rights Reserved.

#pragma once

#include <folly/Optional.h>
#include <folly/dynamic.h>
#include <ABI36_0_0jsi/ABI36_0_0jsi.h>

#include <ABI36_0_0React/core/ShadowNode.h>
#include <ABI36_0_0React/core/StateData.h>
#include <ABI36_0_0React/mounting/ShadowTreeRegistry.h>
#include <ABI36_0_0React/uimanager/ComponentDescriptorRegistry.h>
#include <ABI36_0_0React/uimanager/UIManagerDelegate.h>

namespace ABI36_0_0facebook {
namespace ABI36_0_0React {

class UIManager {
 public:
  void setShadowTreeRegistry(ShadowTreeRegistry *shadowTreeRegistry);

  void setComponentDescriptorRegistry(
      const SharedComponentDescriptorRegistry &componentDescriptorRegistry);

  /*
   * Sets and gets the UIManager's delegate.
   * The delegate is stored as a raw pointer, so the owner must null
   * the pointer before being destroyed.
   */
  void setDelegate(UIManagerDelegate *delegate);
  UIManagerDelegate *getDelegate();

 private:
  friend class UIManagerBinding;
  friend class Scheduler;

  SharedShadowNode createNode(
      Tag tag,
      std::string const &componentName,
      SurfaceId surfaceId,
      const RawProps &props,
      SharedEventTarget eventTarget) const;

  SharedShadowNode cloneNode(
      const SharedShadowNode &shadowNode,
      const SharedShadowNodeSharedList &children = nullptr,
      const RawProps *rawProps = nullptr) const;

  void appendChild(
      const SharedShadowNode &parentShadowNode,
      const SharedShadowNode &childShadowNode) const;

  void completeSurface(
      SurfaceId surfaceId,
      const SharedShadowNodeUnsharedList &rootChildren) const;

  void setNativeProps(
      const SharedShadowNode &shadowNode,
      const RawProps &rawProps) const;

  void setJSResponder(
      const SharedShadowNode &shadowNode,
      const bool blockNativeResponder) const;

  void clearJSResponder() const;

  /*
   * Returns layout metrics of given `shadowNode` relative to
   * `ancestorShadowNode` (relative to the root node in case if provided
   * `ancestorShadowNode` is nullptr).
   */
  LayoutMetrics getRelativeLayoutMetrics(
      const ShadowNode &shadowNode,
      const ShadowNode *ancestorShadowNode) const;

  /*
   * Creates a new shadow node with given state data, clones what's necessary
   * and performs a commit.
   */
  void updateState(
      const SharedShadowNode &shadowNode,
      const StateData::Shared &rawStateData) const;

  void dispatchCommand(
      const SharedShadowNode &shadowNode,
      std::string const &commandName,
      folly::dynamic const args) const;

  ShadowTreeRegistry *shadowTreeRegistry_;
  SharedComponentDescriptorRegistry componentDescriptorRegistry_;
  UIManagerDelegate *delegate_;
};

} // namespace ABI36_0_0React
} // namespace ABI36_0_0facebook
